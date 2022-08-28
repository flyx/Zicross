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
  in rec {
    packages = rec {
      demo = pkgs.buildGoModule {
        inherit pname version;
        src = ./.;
        subPackages = [ "zicross_demo_go" ];
        vendorSha256 = "T2Sd5m5ljhNOSx6esfEubUvcmno4MHJy+98ivi5gZ8Q=";
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = with pkgs; [ mySDL2 SDL2_ttf SDL2_image ];
        targetSharePath="${placeholder "out"}/share";
        # workaround for buildGoModule not being able to take sources in a `go`
        # directory as input
        postUnpack = ''
          mv "$sourceRoot" source
          sourceRoot=source
        '';
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
      };
      win64Zip = pkgs.packageForWindows (demo.overrideAttrs {
        GOOS = "windows";
        GOARCH = "amd64";
      }) {
        targetSystem = "x86_64-windows";
        appendExe = [ "zicross_demo_go" ];
        guiSubsystem = true;
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