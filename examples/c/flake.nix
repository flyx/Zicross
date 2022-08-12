{
  inputs = {
    zicross.url = github:flyx/Zicross;
    nixpkgs.url = github:NixOS/nixpkgs/nixos-22.05;
    utils.url   = github:numtide/flake-utils;
  };
  outputs = {self, zicross, nixpkgs, utils}:
      with utils.lib; eachSystem allSystems (system: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        zicross.overlays.zig
        zicross.overlays.debian
        zicross.overlays.windows
      ];
    };
    frameworks = if pkgs.lib.hasSuffix "darwin" system then
      with pkgs.darwin.apple_sdk.frameworks; [
        AudioToolbox Carbon Cocoa CoreAudio CoreFoundation CoreHaptics
        ForceFeedback GameController IOKit Metal QuartzCore
    ] else [];
    
    pname = "zicross_demo_c";
    version = "0.1.0";
  in rec {
    packages = rec {
      demo = pkgs.zigStdenv.mkDerivation {
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = with pkgs; [ SDL2 libiconv ];
        inherit pname version;
        makeFlags = [ "DESTDIR=${placeholder "out"}" ];
        targetSharePath="${placeholder "out"}/share";
        src = ./.;
        postConfigure = ''
          cat <<EOF >resources.h
          static const char *resources_data = "$targetSharePath/logo.txt";
          EOF
        '';
        preBuild = ''
          export CFLAGS="$(pkg-config --cflags sdl2)"
          export LDFLAGS="$(pkg-config --libs sdl2)"
        '';
        preInstall = ''
          mkdir -p $out/share
          cp ${zicross.lib.logo_data} $out/share/logo.txt
        '';
        meta = {
          maintainers = [ "Felix Krause <contact@flyx.org>" ];
          description = "Zicross Demo App (in C)";
        };
      };
      rpiDeb = pkgs.packageForDebian demo {
        targetSystem = "armv7l-hf-multiplatform";
        pkgConfigPrefix = "/usr/lib/arm-linux-gnueabihf/pkgconfig";
        name = pname;
        inherit version;
        deps = {
          sdl2 = {
            path = "debian/pool/main/libs/libsdl2/libsdl2-2.0-0_2.0.14+dfsg2-3_armhf.deb";
            sha256 = "1z3bcjx225gp6lcbcd7h15cvhjik089y5pgivl2v3kfp61zm9wv4";
            dev = {
              path = "debian/pool/main/libs/libsdl2/libsdl2-dev_2.0.14+dfsg2-3_armhf.deb";
              sha256 = "17d8qms1p7961kl0g7hgmkn0qx9avjnxwlmsvx677z5xb8vchl3y";
            };
            packageName = "libsdl2-2.0-0";
            minVersion = "2.0.0";
          };
          libcrypt = {
            path = "debian/pool/main/libx/libxcrypt/libcrypt1_4.4.18-4_armhf.deb";
            sha256 = "0mcr0s5dwcj8rlr70sf6n3271pg7h73xk6zb8r7xvhp2fm51fyri";
            packageName = "libcrypt1";
            minVersion = "1:4.4.18";
          };
        };
      };
      win64Zip = pkgs.packageForWindows demo {
        targetSystem = "x86_64-windows";
        deps = {
          sdl2 = {
            tail = "SDL2-2.0.22-1-any.pkg.tar.zst";
            sha256 = "13v4wavbxzdnmg6b7qrv7031dmdbd1rn6wnsk9yn4kgs110gkk90";
            postPatch = ''
              ${pkgs.gnused}/bin/sed -i "s/-lSDL2main//g" upstream/clang64/lib/pkgconfig/sdl2.pc
            '';
          };
          iconv = {
            tail = "libiconv-1.16-2-any.pkg.tar.zst";
            sha256 = "0kwc5f60irrd5ayjr0f103f7qzll9wghcs9kw1v17rj5pax70bxf";
          };
          vulkan = {
            tail = "vulkan-loader-1.3.211-1-any.pkg.tar.zst";
            sha256 = "0n9wnrcclvxj7ay14ia679s2gcj5jyjgpg53j51yfdn48wlqi40l";
          };
          libcpp = {
            tail = "libc++-14.0.3-1-any.pkg.tar.zst";
            sha256 = "1r73zs9naislzzjn7mr3m8s6pikgg3y4mv550hg09gcsjc719kzz";
          };
          unwind = {
            tail = "libunwind-14.0.3-1-any.pkg.tar.zst";
            sha256 = "1lxb0qgnl9fbdmkmj53zjg8i9q5hv0pa83bkmraf2raflpm2yrs5";
          };
        };
      };
    };
    defaultPackage = packages.demo;
  });
}