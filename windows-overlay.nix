final: prev: {
  buildForWindows =
    # the original package to override
    pkg:
    # where to find *.pc files in the given MSYS2 packages.
    { pkgConfigPrefix ? "/clang64/lib/pkgconfig"
      # set of MSYS2 packages to download, patch and put into buildInputs
    , deps ? { }
      # list of executables in /bin where a `.exe` should be appended.
    , appendExe ? [ ]
      # name of the target system (in NixOS terminology)
    , targetSystem }:

    let
      patch-pkg-config = import ./patch-pkg-config.nix;
      fetchMsys = { tail, sha256, ... }:
        builtins.fetchurl {
          url =
            "https://mirror.msys2.org/mingw/clang64/mingw-w64-clang-x86_64-${tail}";
          inherit sha256;
        };
      pkgsFromPacman = name: input:
        let src = fetchMsys input;
        in prev.stdenvNoCC.mkDerivation
        ((builtins.removeAttrs input [ "tail" "sha256" ]) // {
          name = "msys2-${name}";
          inherit src;
          phases = [ "unpackPhase" "patchPhase" "installPhase" ];
          nativeBuildInputs = [ prev.gnutar prev.zstd ];
          unpackPhase = ''
            runHook preUnpack
            mkdir -p upstream
            ${prev.gnutar}/bin/tar -xvpf $src -C upstream \
            --exclude .PKGINFO --exclude .INSTALL --exclude .MTREE --exclude .BUILDINFO
            runHook postUnpack
          '';
          patchPhase = ''
            runHook prePatch
            shopt -s globstar
            for pcFile in upstream/**/pkgconfig/*.pc; do
              ${patch-pkg-config prev} $pcFile $out
            done
            find -type f -name "*.a" -not -name "*.dll.a" -not -name "*main.a" -delete
            runHook postPatch
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/
            cp -rt $out upstream/*
            runHook postInstall
          '';
        });
    in pkg.overrideAttrs (origAttrs: {
      inherit pkgConfigPrefix appendExe;
      ZIG_TARGET = prev.zig.systemName.${targetSystem};
      buildInputs = prev.lib.mapAttrsToList pkgsFromPacman deps;
      targetSharePath = "../share";
      postConfigure = ''
        for item in $buildInputs; do
          export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$item$pkgConfigPrefix"
          export CFLAGS="$CFLAGS -I$item/clang64/include"
        done
      '' + (origAttrs.postConfigure or "");
      postInstall = (origAttrs.postInstall or "") + ''
        for item in $buildInputs; do
          cp -t $out/bin $item/clang64/bin/*.dll | true # allow deps without dlls
        done
        for item in $appendExe; do
          mv $out/bin/$item $out/bin/$item.exe
        done
      '';
    });

  packageForWindows =
    # the original package to override
    pkg:
    # where to find *.pc files in the given MSYS2 packages.
    { pkgConfigPrefix ? "/clang64/lib/pkgconfig"
      # set of MSYS2 packages to download, patch and put into buildInputs
    , deps ? { }
      # list of executables in /bin where a `.exe` should be appended.
    , appendExe ? [ ]
      # name of the target system (in NixOS terminology)
    , targetSystem }:

    let
      src = final.buildForWindows pkg {
        inherit pkgConfigPrefix deps appendExe targetSystem;
      };
    in prev.stdenvNoCC.mkDerivation {
      name = "${src.name}-win64.zip";
      unpackPhase = ''
        packDir=${src.name}-win64
        mkdir -p $packDir
        cp -rt $packDir --no-preserve=mode ${src}/*
      '';
      buildPhase = ''
        ${prev.zip}/bin/zip -r $packDir.zip $packDir
      '';
      installPhase = ''
        cp $packDir.zip $out
      '';
    };
}
