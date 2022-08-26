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
    
    pname = "zicross_demo_go";
    version = "0.1.0";
  in rec {
    packages = rec {
      demo = pkgs.buildGo118Module {
        inherit pname version;
        src = ./.;
        modRoot = ".";
        vendorSha256 = "T2Sd5m5ljhNOSx6esfEubUvcmno4MHJy+98ivi5gZ8Q=";
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = with pkgs; [ SDL2 SDL2_ttf SDL2_image ];
        targetSharePath="${placeholder "out"}/share";
        postConfigure = ''
          cat <<EOF >generated.go
          package main
          
          const LogoPath = "$targetSharePath/logo.txt";
          EOF
        '';
        preBuild = ''
          export GOPATH=$(pwd)/go
        '';
        postBuild = ''
          mv "$GOPATH/bin/go" "$GOPATH/bin/zicross_demo_go"
        '';
        preInstall = ''
          mkdir -p $out/share
          cp ${zicross.lib.logo_data} $out/share/logo.txt
        '';
      };
    };
    defaultPackage = packages.demo;
  });
}