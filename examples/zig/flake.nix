{
  inputs = {
    zicross.url = "github:flyx/Zicross";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, zicross, nixpkgs, utils }:
    with utils.lib;
    eachSystem allSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            zicross.overlays.zig
            zicross.overlays.debian
            zicross.overlays.windows
          ];
        };
        zig-sdl = pkgs.fetchFromGitHub {
          owner = "MasterQ32";
          repo = "SDL.zig";
          rev = "00b43568854f14e3bab340a4e062776ecb44a727";
          sha256 = "5z2KgiVxGzVEJXjHunOzBaLLI5PkIPWN4g3HN+G8jgQ=";
        };
        zigPackages = let
          build_options = {
            name = "build_options";
            src = ./.;
            main = "zig-sdl-build-options.zig";
            dependencies = [ ];
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
      in rec {
        packages = rec {
          demo = pkgs.buildZig {
            buildInputs = [ pkgs.SDL2 pkgs.libiconv ];
            pname = "zicross_demo_zig";
            version = "0.1.0";
            src = ./.;
            zigExecutables = [{
              name = "zicross_demo_zig";
              file = "main.zig";
              dependencies = zigPackages;
              install = true;
            }];
            zigTests = [{
              name = "loadTest";
              description = "tests loading the logo";
              file = "main.zig";
              src = ./.;
              dependencies = zigPackages;
            }];
            postConfigure = ''
              cat <<EOF >resources.zig
              pub const data = "$targetSharePath/logo.txt";
              EOF
            '';
            # use upstream logo file for testing
            preCheck = ''
              cat <<EOF >resources.zig
              pub const data = "${zicross.lib.logo_data}";
              EOF
            '';
            preInstall = ''
              mkdir -p $out/share
              cp ${zicross.lib.logo_data} $out/share/logo.txt
            '';
            meta = {
              maintainers = [ "Felix Krause <contact@flyx.org>" ];
              description = "Zicross Demo App";
            };
          };
          rpiDeb = pkgs.packageForDebian demo {
            targetSystem = "armv7l-hf-multiplatform";
            pkgConfigPrefix = "/usr/lib/arm-linux-gnueabihf/pkgconfig";
            name = "zicross-demo-zig";
            version = "0.1.0";
            deps = {
              sdl2 = {
                path =
                  "debian/pool/main/libs/libsdl2/libsdl2-2.0-0_2.0.14+dfsg2-3_armhf.deb";
                sha256 = "1z3bcjx225gp6lcbcd7h15cvhjik089y5pgivl2v3kfp61zm9wv4";
                dev = {
                  path =
                    "debian/pool/main/libs/libsdl2/libsdl2-dev_2.0.14+dfsg2-3_armhf.deb";
                  sha256 =
                    "17d8qms1p7961kl0g7hgmkn0qx9avjnxwlmsvx677z5xb8vchl3y";
                };
                packageName = "libsdl2-2.0-0";
                minVersion = "2.0.0";
              };

              libcrypt = {
                path =
                  "debian/pool/main/libx/libxcrypt/libcrypt1_4.4.18-4_armhf.deb";
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
