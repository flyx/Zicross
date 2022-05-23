{
  inputs = {
    zig-flake.url = github:arqv/zig-overlay;
  };
  outputs = {self, zig-flake}: {
    overlays.zig = import ./zig-overlay.nix { inherit zig-flake; };
    overlays.debian = import ./debian-overlay.nix;
    overlays.windows = import ./windows-overlay.nix;
    lib = let
      patch-pkg-config = import ./patch-pkg-config.nix;
    in {
      logo_data = ./logo_matrix.txt; 
    };
  };
}