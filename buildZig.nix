{lib, zig, stdenvNoCC, pkg-config, system, onZigMaster ? false}:

{ name ? "${args'.pname}-${args'.version}"
# pkg-config prefix within buildInputs. this may depend on
# the target system, e.g. debian on arm uses /usr/lib/arm-linux-gnueabihf/pkgconfig
, pkgConfigPrefix ? "/lib/pkgconfig"
# Build inputs in the format of the target system.
# May be foreign packages, e.g. from Debian.
, buildInputs ? []
# as specified for mkDerivation
, nativeBuildInputs ? []
# buildZig autogenerates a `build.zig` file.
# You can customize it with the following two attributes:
#   - buildZigAdditionalHeader is inserted after the std import
#   - buildZigAdditional is inserted into the build function after
#     all steps have been declared.
, buildZigAdditionalHeader ? ""
, buildZigAdditional ? ""
# list of executables to be built from zig code.
# each list item is to have the following structure:
# 
#     {
#       name         = <output name>;
#       file         = <string: relative path to zig file containing `pub fn main`>;
#       dependencies = <list of zig packages>; # optional
#       install      = <bool>;                 # optional
#       target       = <attrset>;              # optional
#       stage1       = <bool>;                 # optional, only for zig stage2 compiler
#       generators   = [
#         {
#           name = <output name>; # name of a zigExecutable
#           # TODO: args? working directory?
#         } ...
#       ]; # optional
#     }
, zigExecutables ? []
# list of libraries to be built from zig code.
# each list item is to have the following structure:
#
#     {
#       name         = <output name>;
#       file         = <string: relative path to main zig file>;
#       dependencies = <list of zig packages>; # optional
#       install      = <bool>;                 # optional
#       target       = <attrset>;              # optional
#       stage1       = <bool>;                 # optional, only for zig stage2 compiler
#       generators   = [ … ];                  # optional, see above
#     }
, zigLibraries ? []
# list of tests to run after building.
# each list item is to have the following structure:
#
#     {
#       name = <name the tests can be called with (via `zig build $name`)>;
#       description = <string that describes the test>;
#       file = <string: relative path to zig file containing the test(s)>;
#       dependencies = <list of zig packages>;
#       stage1       = <bool>;                 # optional, only for zig stage2 compiler
#       generators   = [ … ];                  # optional, see above
#     }
, zigTests ? []
, ...}@args':

let
  declZigPackage = with builtins; ctx: package: if hasAttr package.name ctx.state then ctx else let
    deps = foldl' declZigPackage ctx (package.dependencies or [ ]);
  in rec {
    state = deps.state // { "${package.name}" = "p${toString (length (attrNames deps.state))}"; };
    code = deps.code + ''
      const ${state.${package.name}} = std.build.Pkg{
        .name = "${package.name}",
        .${if onZigMaster then "source" else "path"} = .{.path = "${if (builtins.hasAttr "src" package) then "${package.src}/" else ""}${package.main}"},
        .dependencies = &.{
          ${lib.concatStringsSep ",\n" (map (package: state.${package.name}) (package.dependencies or [ ]))}
        }
      };
    '';
  };
in stdenvNoCC.mkDerivation ((
  builtins.removeAttrs args' [
    "zigExecutables" "zigLibraries" "zigTests"
    "pkgConfigPrefix" "buildZigAdditional" "buildZigAdditionalHeader"
  ]
) // {
  # needed because args' doesn't contain the default values
  inherit buildZigAdditional buildZigAdditionalHeader pkgConfigPrefix;
  nativeBuildInputs = nativeBuildInputs ++ [ pkg-config zig ];
  doCheck = builtins.length zigTests > 0;
  configurePhase = let
    fullDeps = builtins.foldl' declZigPackage { state = {}; code = ""; }
        (lib.lists.flatten (builtins.catAttrs "dependencies" (zigExecutables ++ zigLibraries ++ zigTests)));
    needsTarget = builtins.foldl' (x: y: x || (!(builtins.hasAttr "target" y))) false (zigLibraries ++ zigExecutables);
    toStructLiteral = set: ''
      .{${lib.concatStrings (lib.mapAttrsToList (name: value: ".${name} = .${value}, ") set)}}
    '';
  in ''
    targetSharePath=${if builtins.hasAttr "targetSharePath" args' then args'.targetSharePath else "$out/share"}
    runHook preConfigure
    mycat() {
      local REPLY
      read -r -d "" || printf '%s' "$REPLY"
    }

    PKG_CONFIG_PATH=
    PKG_CONFIG_LIBS=
    for input in $buildInputs; do
      curPath=$input$pkgConfigPrefix
      PKG_CONFIG_PATH=$curPath:$PKG_CONFIG_PATH
      for file in $curPath/*.pc; do
        [ -e "$file" ] || continue
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
    
    fn testEmitOption(
      emit_bin: bool,
      name: []const u8,
    ) std.build.LibExeObjStep.EmitOption {
      return if (!emit_bin) std.build.LibExeObjStep.EmitOption.default else
        std.build.LibExeObjStep.EmitOption{.emit_to = name};
    }

    pub fn build(b: *std.build.Builder) !void {
      ${if needsTarget then "const target = b.standardTargetOptions(.{});" else ""}
      const mode = b.standardReleaseOptions();
      
    ${if builtins.length zigTests > 0 then ''
      const test_filter =
        b.option([]const u8, "test-filter", "filters tests when testing");
      const emit_bin = (
        b.option(bool, "emit_bin", "emit binaries for tests")
      ) orelse false;
    '' else ""}
    
    ${lib.concatStrings (lib.imap1 (i: exec: let
      v = "exec${toString i}";
    in ''
      const ${v} = b.addExecutable("${exec.name}", "${exec.file}");
      ${v}.setTarget(${if (builtins.hasAttr "target" exec) then (toStructLiteral exec.target) else "target"});
      ${v}.setBuildMode(mode);
      ${v}.main_pkg_path = ".";
      ${if (exec.install or false) then ''
        ${v}.linkage = .dynamic;
        ${v}.install();
        ${if buildInputs != [ ] then "addPkgConfigLibs(${v});" else ""}
      '' else ""}
      ${lib.concatStrings (builtins.map (pkg: ''
        ${v}.addPackage(${fullDeps.state.${pkg.name}});
      '') (exec.dependencies or [ ]))}
      ${lib.concatStrings (builtins.map (gen: ''
        ${v}.step.dependOn(&exec${builtins.toString (lib.findFirst (x: x.name == gen.name) null (lib.imap1 (i: v: {i = i; name = v.name;}) zigExecutables)).i}_run.step);
      '') (exec.generators or [ ]))}
      ${if (exec.stage1 or false) then "${v}.use_stage1 = true;" else ""}
      
      const ${v}_step = b.step("${exec.name}", "${exec.description or ""}");
      ${v}_step.dependOn(&${v}.step);
      const ${v}_run = ${v}.run();
      ${v}_run.cwd = ".";
      ${v}_run.step.dependOn(&${v}.step);
      
    '') zigExecutables)}
    
    ${lib.concatStrings (lib.imap1 (i: ziglib: let
      v = "lib${toString i}";
    in ''
      const ${v} = b.addSharedLibrary("${ziglib.name}", "${ziglib.file}", .unversioned);
      ${v}.setTarget(${if (builtins.hasAttr "target" ziglib) then (toStructLiteral ziglib.target) else "target"});
      ${v}.setBuildMode(mode);
      ${v}.main_pkg_path = ".";
      ${if (ziglib.install or false) then ''
        ${v}.linkage = .dynamic;
        ${v}.install();
        ${if buildInputs != [ ] then "addPkgConfigLibs(${v});" else ""}
      '' else ""}
      ${lib.concatStrings (builtins.map (pkg: ''
        ${v}.addPackage(${fullDeps.state.${pkg.name}});
      '') (ziglib.dependencies or [ ]))}
      ${lib.concatStrings (builtins.map (gen: ''
        ${v}.step.dependOn(&exec${builtins.toString (lib.findFirst (x: x.name == gen.name) null (lib.imap1 (i: v: {i = i; name = v.name;}) zigExecutables)).i}_run.step);
      '') (ziglib.generators or [ ]))}
      ${if (ziglib.stage1 or false) then "${v}.use_stage1 = true;" else ""}
      
      const ${v}_step = b.step("${ziglib.name}", "${ziglib.description or ""}");
      ${v}_step.dependOn(&${v}.step);
      
    '') zigLibraries)}
    
    ${lib.concatStrings (lib.imap1 (i: test: let
      v = "test${toString i}";
    in ''
      const ${v} = b.addTest("${test.file}");
      ${lib.concatStrings (builtins.map (pkg: ''
        ${v}.addPackage(${fullDeps.state.${pkg.name}});
      '') (test.dependencies or [ ]))}
      ${lib.concatStrings (builtins.map (gen: ''
        ${v}.step.dependOn(&exec${builtins.toString (lib.findFirst (x: x.name == gen.name) null (lib.imap1 (i: v: {i = i; name = v.name;}) zigExecutables)).i}_run.step);
      '') (test.generators or [ ]))}
      ${v}.setFilter(test_filter);
      ${v}.emit_bin = testEmitOption(emit_bin, "${test.name}");
      ${v}.main_pkg_path = ".";
      ${if (test.stage1 or false) then "${v}.use_stage1 = true;" else ""}
      const ${v}_step = b.step("${test.name}", "${test.description or ""}");
      ${v}_step.dependOn(&${v}.step);
    '') zigTests)}
    ${if zigTests != [ ] then ''
      const test_step = b.step("test", "run all tests");
      ${lib.concatStrings (lib.imap1 (i: _: ''
        test_step.dependOn(&test${toString i}.step);
      '') zigTests)}
    '' else ""}
    EOF
    printenv buildZigAdditional >>build.zig
    echo "}" >>build.zig
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    export ZIG_LOCAL_CACHE_DIR=$(pwd)/zig-cache
    export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
    export NIX_CFLAGS_COMPILE=
    export NIX_LDFLAGS=
    ADDITIONAL_FLAGS=
    if ! [ -z ''${ZIG_TARGET+x} ]; then
      ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -Dtarget=$ZIG_TARGET"
    fi
    
    export PATH=${pkg-config}/bin:$PATH # so that zig build sees it
    ${zig}/bin/zig build $ADDITIONAL_FLAGS
    runHook postBuild
  '';
  # don't check when cross-compiling
  checkPhase = if zigTests == [ ] then "" else ''
    if [ -z ''${ZIG_TARGET+x} ]; then
      runHook preCheck
      ${zig}/bin/zig build test $ADDITIONAL_FLAGS
      runHook postCheck
    fi
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r zig-out/* $out/
    runHook postInstall
  '';
})