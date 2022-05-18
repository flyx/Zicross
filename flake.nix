{
  inputs = {
    zig-overlay.url = github:arqv/zig-overlay;
  };
  outputs = {self, zig-overlay}: {
    lib = {
      logo_data = ./logo_matrix.txt;
      buildZig = hostPkgs: targetSystem: args@{
        buildInputs,
        pkgConfigPrefix ? "/usr/lib/pkgconfig",
        nativeBuildInputs ? [],
        buildZigAdditionalHeader ? "",
        buildZigAdditional ? "",
        zigExecutables ? {},
        zigLibraries ? {},
        ...
      }: let
        zig = zig-overlay.packages.${hostPkgs.system}."0.9.1".overrideAttrs (old: {
          installPhase = let
            armFeatures = builtins.fetchurl {
              url = "https://sourceware.org/git/?p=glibc.git;"    +
                    "a=blob_plain;f=sysdeps/arm/arm-features.h;"  +
                    "h=80a1e2272b5b4ee0976a410317341b5ee601b794;" +
                    "hb=0281c7a7ec8f3f46d8e6f5f3d7fca548946dbfce";
              name = "glibc-2.35_arm-features.h";
              sha256 =
                "1g4yb51srrfbd4289yj0vrpzzp2rlxllxgz8q4a5zw1n654wzs5a";
            };
          in old.installPhase + "\ncp ${armFeatures} " +
            "$out/lib/libc/glibc/sysdeps/arm/arm-features.h";
        });
        zigSystem = {
          "aarch64-darwin" = "aarch64-macos";
          "armv7l-hf-multiplatform" = "arm-linux-gnueabihf";
        };
        declZigPackage = with builtins; ctx: package: if hasAttr package.name ctx.state then ctx else let
          deps = foldl' declZigPackage ctx package.dependencies;
        in rec {
          state = deps.state // { "${package.name}" = "p${toString (length (attrNames deps.state))}"; };
          code = deps.code + ''
            const ${state.${package.name}} = std.build.Pkg{
              .name = "${package.name}",
              .path = .{.path = "${package.src}/${package.main}"},
              .dependencies = &.{
                ${hostPkgs.lib.concatStringsSep ",\n" (map (package: state.${package.name}) package.dependencies)}
              }
            };
          '';
        };
      in hostPkgs.stdenvNoCC.mkDerivation (
        (builtins.removeAttrs args [ "zigExecutables" "zigLibraries" ]) //
      {
        inherit buildZigAdditional buildZigAdditionalHeader;
        nativeBuildInputs = nativeBuildInputs ++ [ hostPkgs.pkg-config ];
        configurePhase = let
          fullDeps = builtins.foldl' declZigPackage { state = {}; code = ""; }
              (hostPkgs.lib.lists.flatten (builtins.catAttrs "dependencies" zigExecutables));
        in ''
          runHook preConfigure
          mycat() {
            local REPLY
            read -r -d "" || printf '%s' "$REPLY"
          }

          PKG_CONFIG_PATH=
          PKG_CONFIG_LIBS=
          for input in $buildInputs; do
            curPath=$input${pkgConfigPrefix}
            PKG_CONFIG_PATH=$curPath:$PKG_CONFIG_PATH
            for file in $curPath/*.pc; do
              filename=$(basename -- $file)
              PKG_CONFIG_LIBS="$PKG_CONFIG_LIBS ''${filename%.pc}"
            done
          done
          export PKG_CONFIG_PATH

          mycat >build.zig <<-EOF
          const std = @import("std");
          EOF
          printenv buildZigAdditionalHeader >>build.zig
          mycat >>build.zig <<-EOF
          ${fullDeps.code}

          fn addPkgConfigLibs(step: *std.build.LibExeObjStep) void {
          EOF
          for lib in $PKG_CONFIG_LIBS; do
          mycat >>build.zig <<-EOF
            step.linkSystemLibrary("$lib");
          EOF
          done
          mycat >>build.zig <<-EOF
            step.linkLibC();
          }

          pub fn build(b: *std.build.Builder) !void {
            const target = b.standardTargetOptions(.{});
            const mode = b.standardReleaseOptions();
          ${hostPkgs.lib.concatStrings (builtins.map (exec: ''
            const ${exec.name} = b.addExecutable("${exec.name}", "${exec.file}");
            ${exec.name}.setTarget(target);
            ${exec.name}.setBuildMode(mode);
            ${exec.name}.linkage = .dynamic;
            addPkgConfigLibs(${exec.name});
            ${hostPkgs.lib.concatStrings (builtins.map (pkg: ''
              ${exec.name}.addPackage(${fullDeps.state.${pkg.name}});
            '') exec.dependencies)}
            ${exec.name}.install();
          '') zigExecutables)}
          EOF
          printenv buildZigAdditional >>build.zig
          echo "}" >>build.zig
          runHook postConfigure
        '';
        buildPhase = ''
          runHook preBuild
          cat build.zig
          export ZIG_LOCAL_CACHE_DIR=$(pwd)/zig-cache
          export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
          export NIX_CFLAGS_COMPILE=
          export NIX_LDFLAGS=
          export PATH=${hostPkgs.pkg-config}/bin:$PATH # so that zig build sees it
          ${zig}/bin/zig build -Dtarget=${zigSystem.${targetSystem}} $CFLAGS $LDFLAGS
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r zig-out/* $out/
          runHook postInstall
        '';
      });
      crossBuild = hostPkgs: pkgGen: foreignTargets: let
        patch-pkg-config = hostPkgs.writeShellScript "patch-pkg-config" ''
          pcFile=$1
          storePath=$2
          echo patching $pcFile to store path $storePath
          ${hostPkgs.gnused}/bin/sed -i "s:=/:=$storePath/:g" $pcFile
        '';
        builders = {
          debian = gen: targetSystem: deps: pkgConfigPrefix: let
            fetchDeb = {path, sha256, ...}: builtins.fetchurl {
              url = "http://ftp.de.debian.org/debian/${path}";
              inherit sha256;
            };
            pkgFromDebs = name: input: let
              hasDev = builtins.hasAttr "dev" input;
              srcs = [ (fetchDeb input)] ++
                (if hasDev then [ (fetchDeb input.dev) ] else []);
            in hostPkgs.stdenvNoCC.mkDerivation {
              name = "dpkg-${name}";
              inherit srcs;
              phases = ["unpackPhase" "patchPhase" "installPhase"];
              unpackPhase = ''
                mkdir -p upstream
                ${hostPkgs.dpkg}/bin/dpkg-deb -x ${builtins.elemAt srcs 0} upstream
              '' + (if hasDev then ''
                ${hostPkgs.dpkg}/bin/dpkg-deb -x ${builtins.elemAt srcs 1} upstream
              '' else "");
              patchPhase = ''
                shopt -s globstar
                for pcFile in upstream/**/pkgconfig/*.pc; do
                  ${patch-pkg-config} $pcFile $out
                done
              '';
              installPhase = ''
                mkdir -p $out/
                cp -r upstream/* $out/
              '';
            };
            debianArch = {
              "armv7l-hf-multiplatform" = "armhf";
            };
            raw = gen {
              inherit targetSystem pkgConfigPrefix;
              buildInputs = hostPkgs.lib.mapAttrsToList pkgFromDebs deps;
            };
          in raw // {
            deb = hostPkgs.stdenvNoCC.mkDerivation {
              CONTROL = ''
                Package: ${raw.pname}
                Version: ${raw.version}
                Section: base
                Priority: optional
                Architecture: ${debianArch.${targetSystem}}
                Depends: libcairo2 (>= 1.16.0)
                Maintainer: Karl Koch <contact@example.com>
                Description: Nix+Go Demo Debian Package
              '';
            };
          };
        };
      in builtins.mapAttrs (
        name: value: builders.${value.kind} pkgGen value.target value.deps value.pkgConfigPrefix
      ) foreignTargets;
    };
  };
}