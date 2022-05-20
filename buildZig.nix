# provided by the flake
{zig-overlay}:
# instantiates a builder running on a host for a target
{
  # instance of nixpkgs for the host system
  hostPkgs, 
  # name of the target system (triplet as used by NixOS)
  targetSystem
}:
# configures the zig builder for your project
args@{
  # these may be provided by the cross-build environment,
  # in which case they are e.g. debian packages.
  buildInputs,
  # pkg-config prefix within buildInputs. this may depend on
  # the target system, e.g. debian on arm uses /usr/lib/arm-linux-gnueabihf/pkgconfig
  pkgConfigPrefix ? "/lib/pkgconfig",
  nativeBuildInputs ? [],
  # buildZig autogenerates a `build.zig` file.
  # You can customize it with the following two attributes:
  #   - buildZigAdditionalHeader is inserted after the std import
  #   - buildZigAdditional is inserted into the build function after
  #     all steps have been declared.
  buildZigAdditionalHeader ? "",
  buildZigAdditional ? "",
  # list of executables to be built from zig code.
  # each list item is to have the following structure:
  # 
  #     {
  #       name = <valid zig identifier>;
  #       file = <string: relative path to zig file containing `pub fn main`>;
  #       dependencies = <list of zig packages>;
  #     }
  zigExecutables ? [],
  # TODO: currently ignored.
  zigLibraries ? [],
  ...
}: let
  zig = import ./zig.nix {
    inherit (hostPkgs) system;
    inherit zig-overlay;
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
    targetSharePath=${if builtins.hasAttr "targetSharePath" args then args.targetSharePath else "$out/share"}
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
    ${zig}/bin/zig build -Dtarget=${zig.systemName.${targetSystem}} $CFLAGS $LDFLAGS
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r zig-out/* $out/
    runHook postInstall
  '';
})