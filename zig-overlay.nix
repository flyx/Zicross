# provided by the flake
{zig-flake}:

self: super: {
  zig = zig-flake.packages.${super.system}."0.9.1".overrideAttrs (old: {
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
    # mapping from NixOS system names to what zig expects
    passthru.systemName = {
      "aarch64-darwin" = "aarch64-macos";
      "armv7l-hf-multiplatform" = "arm-linux-gnueabihf";
      "x86_64-windows" = "x86_64-windows-gnu";
    };
  });
  buildZig = self.callPackage (import ./buildZig.nix) { };
}

