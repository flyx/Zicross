{
  inputs = {
    zig-overlay.url = github:arqv/zig-overlay;
  };
  outputs = {self, zig-overlay}: {
    lib = {
      logo_data = ./logo_matrix.txt;
      buildZig = import ./buildZig.nix { inherit zig-overlay; };
      packageDeb = hostPkgs: args@{src, ...}: let
        name = src.deb.Package;
        version = src.deb.Version;
      in hostPkgs.stdenvNoCC.mkDerivation {
        name = "${name}-${version}.deb";
        CONTROL = ''
          Package: ${name}
          Version: ${version}
          Section: base
          Priority: optional
          Architecture: ${src.deb.Architecture}
          Depends: ${src.deb.Depends}
          Maintainer: ${hostPkgs.lib.concatStringsSep ", " src.meta.maintainers}
          Description: ${src.meta.description}
        '';
        unpackPhase = ''
          packDir=${name}_${version}
          mkdir -p $packDir/{DEBIAN,usr}
          cp -rt $packDir/usr ${src}/bin | true # allow missing bin
          if [ -e ${src}/share ]; then
            mkdir -p $packDir/usr/share/${name}
            cp -rt $packDir/usr/share/${name} ${src}/share/* 
          fi
        '';
        configurePhase = ''
          printenv CONTROL > ${name}_${version}/DEBIAN/control
        '';
        buildPhase = ''
          ${hostPkgs.dpkg}/bin/dpkg-deb --build ${name}_${version}
        '';
        installPhase = ''
          cp *.deb $out
        '';
      };
      crossBuild = hostPkgs: pkgGen: foreignTargets: let
        patch-pkg-config = hostPkgs.writeShellScript "patch-pkg-config" ''
          pcFile=$1
          storePath=$2
          echo patching $pcFile to store path $storePath
          ${hostPkgs.gnused}/bin/sed -i "s:=/:=$storePath/:g" $pcFile
        '';
        builders = {
          debian = gen: {name, version, targetSystem, deps, pkgConfigPrefix} : let
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
          in gen {
            inherit targetSystem pkgConfigPrefix;
            buildInputs = hostPkgs.lib.mapAttrsToList pkgFromDebs deps;
            passthru.deb = {
              Package = name;
              Version = version;
              Architecture = debianArch.${targetSystem};
              Depends = hostPkgs.lib.concatStringsSep ", " (
                hostPkgs.lib.mapAttrsToList (key: value: "${value.packageName} (>= ${value.minVersion})") deps
              );
            };
            targetSharePath = "/usr/share/${name}";
          };
        };
      in builtins.mapAttrs (
        name: value: builders.${value.kind} pkgGen {
          inherit (value) name version deps pkgConfigPrefix;
          targetSystem = value.target;
        }
      ) foreignTargets;
    };
  };
}