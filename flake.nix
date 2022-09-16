{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/22.05;
    utils.url = github:numtide/flake-utils;
  };
  outputs = {self, nixpkgs, utils}: {
    overlays.zig     = import ./zig-overlay.nix { };
    overlays.go      = import ./go-overlay.nix;
    overlays.debian  = import ./debian-overlay.nix;
    overlays.windows = import ./windows-overlay.nix;
    lib = let
      patch-pkg-config = import ./patch-pkg-config.nix;
    in {
      logo_data = ./logo_matrix.txt;
      zigOverlayFor = {
        version,
        master ? false,
        patchArmHeader ? true
      }: import ./zig-overlay.nix { inherit version master patchArmHeader; };
    };
  } // (utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.articleServer = pkgs.stdenvNoCC.mkDerivation rec {
      name = "articleServer";
      phases = [ "unpackPhase" "buildPhase" "installPhase" ];
      src = ./.;
      propagatedBuildInputs = [ pkgs.coreutils pkgs.jekyll ];
      SCRIPT = ''
        DIR=$(${pkgs.coreutils}/bin/mktemp -d)
        cd ${builtins.placeholder "out"}/share
        ${pkgs.jekyll}/bin/jekyll serve --disable-disk-cache -d "$DIR"
      '';
      buildPhase = ''
        mv article/testing/* article/
        mv examples article/
      '';
      installPhase = ''
        mkdir -p $out/{bin,share}
        printenv SCRIPT >$out/bin/articleServer
        chmod u+x $out/bin/articleServer
        cp -r article/* $out/share/
      '';
    };
    packages.articleSources = ./article;
  }));
}