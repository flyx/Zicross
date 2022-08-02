# provided by the flake
{zig-flake}:

final: prev: let
  zig = zig-flake.packages.${prev.system}."0.9.1".overrideAttrs (old: let
    macos_sysroot = if prev.stdenv.isDarwin then "${final.darwin.apple_sdk.MacOSX-SDK}" else "";
  in {
    cc_impl = ''
      #!${final.bash}/bin/bash
      env
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
      export ZIG_LOCAL_CACHE_DIR=$(pwd)/zig-cache
      export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
      ${builtins.placeholder "out"}/bin/zig cc $ADDITIONAL_FLAGS $@
    '';
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
    in old.installPhase + ''
      cp ${armFeatures} $out/lib/libc/glibc/sysdeps/arm/arm-features.h
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

