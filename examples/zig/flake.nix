{
  inputs = {
    zicross.url = github:flyx/Zicross;
    nixpkgs.url = github:NixOS/nixpkgs/nixos-21.11;
    utils.url   = github:numtide/flake-utils;
  };
  outputs = {self, zicross, nixpkgs, utils}:
      with utils.lib; eachSystem allSystems (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    frameworks = if pkgs.lib.hasSuffix "darwin" system then
      with pkgs.darwin.apple_sdk.frameworks; [
        AudioToolbox Carbon Cocoa CoreAudio CoreFoundation CoreHaptics
        ForceFeedback GameController IOKit Metal QuartzCore
    ] else [];
    zig-sdl = pkgs.fetchFromGitHub {
      owner = "MasterQ32";
      repo = "SDL.zig";
      rev = "bf72bbef8c1c113b2862ff2fab33b1fedbf159f6";
      sha256 = "9M1cBs4hY4cFp6woqYofyzgCVogAotVKp6n+Hla3w48=";
    };
    zigPackages = let
      build_options = {
        name = "build_options";
        src = ./.;
        main = "zig-sdl-build-options.zig";
        dependencies = [];
      };
      sdl-native = {
        name = "sdl-native";
        src = zig-sdl;
        main = "src/binding/sdl.zig";
        dependencies = [ build_options ];
      };
      sdl2 = {
        name = "sdl2";
        src = zig-sdl;
        main = "src/wrapper/sdl.zig";
        dependencies = [ sdl-native ];
      };
    in [ sdl2 ];
    gen = { buildInputs, targetSystem, pkgConfigPrefix ? "/lib/pkgconfig" }: {
      demo = zicross.lib.buildZig pkgs targetSystem {
        pname = "zicross_demo_zig";
        version = "0.1.0";
        src = ./.;
        inherit buildInputs pkgConfigPrefix;
        zigExecutables = [
          {
            name = "zicross_demo_zig";
            file = "main.zig";
            dependencies = zigPackages;
          }
        ];
        RESOURCES_ZIG = ''
          pub const data = "${zicross.lib.logo_data}";
        '';
        postConfigure = ''
          printenv RESOURCES_ZIG >resources.zig
          ls -alh
        '';
      };
    }; 
    nativePackages = gen {
      buildInputs = [ pkgs.SDL2 pkgs.libiconv ];
      targetSystem = system;
    };
  in rec {
    packages = nativePackages // {
      cross = zicross.lib.crossBuild pkgs gen {
        rpi = {
          kind = "debian";
          target = "armv7l-hf-multiplatform";
          pkgConfigPrefix = "/usr/lib/arm-linux-gnueabihf/pkgconfig";
          deps = {
            sdl2 = {
              path = "pool/main/libs/libsdl2/libsdl2-2.0-0_2.0.14+dfsg2-3_armhf.deb";
              sha256 = "1z3bcjx225gp6lcbcd7h15cvhjik089y5pgivl2v3kfp61zm9wv4";
              dev = {
                path = "pool/main/libs/libsdl2/libsdl2-dev_2.0.14+dfsg2-3_armhf.deb";
                sha256 = "17d8qms1p7961kl0g7hgmkn0qx9avjnxwlmsvx677z5xb8vchl3y";
              };
            };
            libcrypt = {
              path = "pool/main/libx/libxcrypt/libcrypt1_4.4.18-4_armhf.deb";
              sha256 = "0mcr0s5dwcj8rlr70sf6n3271pg7h73xk6zb8r7xvhp2fm51fyri";
            };
          };
        };
      };
    };
    defaultPackage = packages.demo;
  });
}