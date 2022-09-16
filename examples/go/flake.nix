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
        zicross.overlays.go
        zicross.overlays.debian
        zicross.overlays.windows
      ];
    };
    
    pname = "zicross_demo_go";
    version = "0.1.0";
    
    mySDL2 = if pkgs.stdenv.isDarwin then (pkgs.SDL2.override {
      x11Support = false;
    }) else pkgs.SDL2;
    postUnpack = ''
      mv "$sourceRoot" source
      sourceRoot=source
    '';
  in rec {
    packages = rec {
      demo = pkgs.buildGoModule {
        inherit pname version;
        src = ./.;
        subPackages = [ "zicross_demo_go" ];
        vendorSha256 = "5cfp25rEhmnLI/pQXE1+e6kjiYnb7T3nEuoLw2AfEoM=";
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = with pkgs; [ mySDL2 ];
        targetSharePath="${placeholder "out"}/share";
        
        # workaround for buildGoModule not being able to take sources in a `go`
        # directory as input
        overrideModAttrs = (_: {
          inherit postUnpack;
        });
        inherit postUnpack;
        
        postConfigure = ''
          cat <<EOF >zicross_demo_go/generated.go
          package main
          
          const LogoPath = "$targetSharePath/logo.txt";
          EOF
        '';
        preInstall = ''
          mkdir -p $out/share
          cp ${zicross.lib.logo_data} $out/share/logo.txt
        '';
        meta = {
          maintainers = [ "Felix Krause <contact@flyx.org>" ];
          description = "Zicross Demo App (in Go)";
        };
      };
      rpiDeb = pkgs.packageForDebian (demo.overrideAttrs (origAttrs: {
        GOOS = "linux";
        GOARCH = "arm";
      })) {
        targetSystem = "armv7l-hf-multiplatform";
        pkgConfigPrefix = "/usr/lib/arm-linux-gnueabihf/pkgconfig";
        includeDirs = [ "/usr/include" "/usr/include/arm-linux-gnueabihf" ];
        name = "zicross-demo-go";
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
          libx11-dev = {
            path = "debian/pool/main/libx/libx11/libx11-dev_1.7.2-1_armhf.deb";
            sha256 = "0n0r21z7lp582pk51fp8dwaymz3jz54nb26xmfwls7q4xbj5f7wz";
          };
          x11proto-dev = {
            path = "debian/pool/main/x/xorgproto/x11proto-dev_2020.1-1_all.deb";
            sha256 = "1xb5ll2fg3as128m5vi6w5kwbcyc732hljy16i66dllsgmc8smnm";
          };
        };
      };
      win64Zip = pkgs.packageForWindows (demo.overrideAttrs (origAttrs: {
        GOOS = "windows";
        GOARCH = "amd64";
        postConfigure = origAttrs.postConfigure + ''
          export CGO_LDFLAGS="$CGO_LDFLAGS $(pkg-config --libs sdl2)"
        '';
      })) {
        targetSystem = "x86_64-windows";
        deps = {
          sdl2 = {
            tail = "SDL2-2.0.22-1-any.pkg.tar.zst";
            sha256 = "13v4wavbxzdnmg6b7qrv7031dmdbd1rn6wnsk9yn4kgs110gkk90";
            postPatch = ''
              ${pkgs.gnused}/bin/sed -i "s:-lSDL2main:$out/clang64/lib/libSDL2main.a:g" upstream/clang64/lib/pkgconfig/sdl2.pc
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