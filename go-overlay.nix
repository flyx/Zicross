final: prev: {
  buildGoModule = {
    # target OS, or null for native
    GOOS ? null,
    # target architecture, or null for native
    GOARCH ? null,
    ...
  }@args': ((prev.buildGo118Module.override {
    go = prev.go_1_18 // {
      GOOS = if GOOS == null then prev.go_1_18.GOOS else GOOS;
      GOARCH = if GOARCH == null then prev.go_1_18.GOARCH else GOARCH;
      CGO_ENABLED = true;
    };
  }) args').overrideAttrs (origAttrs: {
    configurePhase = origAttrs.configurePhase + ''
      # requires zigStdenv from zig-overlay
      export CC=${prev.zig}/bin/cc
      export LD=${prev.zig}/bin/cc
      export NIX_CFLAGS_COMPILE=
      export NIX_LDFLAGS=
      export CGO_CFLAGS="-Wno-expansion-to-defined -Wno-nullability-completeness"
      ${if prev.stdenv.isDarwin then ''
        buildFlags="$buildFlags -buildmode=pie"
        ldflags="$ldflags -s -w"
      '' else ""}
    '';
  });
}