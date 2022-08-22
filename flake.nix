{
  inputs = {};
  outputs = {self}: {
    overlays.zig = import ./zig-overlay.nix { };
    overlays.debian = import ./debian-overlay.nix;
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
  };
}