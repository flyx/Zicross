# provided by the flake
{
# version. can be a release version or a date.
version ? "0.13.0",
zig-binaries }:

final: prev:
let
  base = zig-binaries.packages.${prev.system}.${version};

  zig = base.overrideAttrs (old:
    let
      macos_sysroot = if prev.stdenv.isDarwin then
        "${final.darwin.apple_sdk.MacOSX-SDK}"
      else
        "";
    in {
      cc_impl = ''
        #!${final.bash}/bin/bash
        ADDITIONAL_FLAGS=
        if ! [ -z ''${ZIG_TARGET+x} ]; then
          ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -target $ZIG_TARGET"
          # don't add the macOS flags when cross-compiling
          NIX_COREFOUNDATION_RPATH=
        fi
        if ! [ -z ''${NIX_COREFOUNDATION_RPATH+x} ]; then
          ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -F$NIX_COREFOUNDATION_RPATH"
          ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -I${macos_sysroot}/usr/include -L${macos_sysroot}/usr/lib -DTARGET_OS_OSX=1 -DTARGET_OS_IPHONE=0"
        fi
        export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-cache"
        export ZIG_GLOBAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR"
        pwd >&2
        ls -alh "$TMPDIR/zig-cache" >&2
        rm -rf "$ZIG_LOCAL_CACHE_DIR"
        ${
          builtins.placeholder "out"
        }/bin/zig cc -gline-tables-only $ADDITIONAL_FLAGS $@
      '';
      installPhase = old.installPhase + ''
        printenv cc_impl >$out/bin/cc
        chmod a+x $out/bin/cc
      '';
      # mapping from NixOS system names to what zig expects
      passthru.systemName = {
        "aarch64-darwin" = "aarch64-macos";
        "armv7l-hf-multiplatform" = "arm-linux-gnueabihf";
        "x86_64-windows" = "x86_64-windows-gnu";
      };
    });
in {
  inherit zig;
  zigStdenv = prev.overrideCC prev.clangStdenv zig;
  buildZig = final.callPackage (import ./buildZig.nix) { };
}
