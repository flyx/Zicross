{
  inputs = {
    zig-overlay.url = github:arqv/zig-overlay;
  };
  outputs = {self, zig-overlay}: {
    lib = let
      patch-pkg-config = pkgs: pkgs.writeShellScript "patch-pkg-config" ''
        pcFile=$1
        storePath=''$2
        origPath=''${3:-/}
        echo patching $pcFile to store path $storePath
        if [[ $origPath == */ ]]; then
          s="s:=$origPath:=$storePath/:g"
        else
          s="s:=$origPath:=$storePath:g"
        fi
        ${pkgs.gnused}/bin/sed -i $s $pcFile
      '';
    in {
      logo_data = ./logo_matrix.txt;
      buildZig = import ./buildZig.nix { inherit zig-overlay; };
      withDebPkgs = hostPkgs: pkgGen: {name, version, pkgConfigPrefix ? "/lib/pkgconfig", deps ? {}, targetSystem}: let
        fetchDeb = {path, sha256, ...}: builtins.fetchurl {
          url = "http://deb.debian.org/${path}";
          inherit sha256;
        };
        pkgFromDebs = name: input: let
          hasDev = builtins.hasAttr "dev" input;
          srcs = [ (fetchDeb input)] ++
            (if hasDev then [ (fetchDeb input.dev) ] else []);
        in hostPkgs.stdenvNoCC.mkDerivation {
          name = "dpkg-${name}";
          inherit srcs;
          phases = ["unpackPhase" "patchPhase" "installPhase"];
          unpackPhase = ''
            mkdir -p upstream
            ${hostPkgs.dpkg}/bin/dpkg-deb -x ${builtins.elemAt srcs 0} upstream
          '' + (if hasDev then ''
            ${hostPkgs.dpkg}/bin/dpkg-deb -x ${builtins.elemAt srcs 1} upstream
          '' else "");
          patchPhase = ''
            shopt -s globstar
            for pcFile in upstream/**/pkgconfig/*.pc; do
              ${patch-pkg-config hostPkgs} $pcFile $out
            done
          '';
          installPhase = ''
            mkdir -p $out/
            cp -rt $out upstream/*
          '';
        };
        debianArch = {
          "armv7l-hf-multiplatform" = "armhf";
        };
      in pkgGen {
        inherit targetSystem pkgConfigPrefix;
        buildInputs = hostPkgs.lib.mapAttrsToList pkgFromDebs deps;
        passthru.deb = {
          Package = name;
          Version = version;
          Architecture = debianArch.${targetSystem};
          Depends = hostPkgs.lib.concatStringsSep ", " (
            hostPkgs.lib.mapAttrsToList (key: value: "${value.packageName} (>= ${value.minVersion})") deps
          );
        };
        targetSharePath = "/usr/share/${name}";
      };
      withMsysPkgs = hostPkgs: pkgGen: {pkgConfigPrefix ? "/lib/pkgconfig", deps ? {}, targetSystem}: let
        fetchMsys = {tail, sha256, ...}: builtins.fetchurl {
          url = "https://mirror.msys2.org/mingw/clang64/mingw-w64-clang-x86_64-${tail}";
          inherit sha256;
        };
        pkgsFromPacman = name: input: let
          src = fetchMsys input;
        in hostPkgs.stdenvNoCC.mkDerivation ((builtins.removeAttrs input [ "tail" "sha256" ]) // {
          name = "msys2-${name}";
          inherit src;
          phases = [ "unpackPhase" "patchPhase" "installPhase" ];
          nativeBuildInputs = [ hostPkgs.gnutar hostPkgs.zstd ];
          unpackPhase = ''
            runHook preUnpack
            mkdir -p upstream
            ${hostPkgs.gnutar}/bin/tar -xvpf $src -C upstream \
            --exclude .PKGINFO --exclude .INSTALL --exclude .MTREE --exclude .BUILDINFO
            runHook postUnpack
          '';
          patchPhase = ''
            runHook prePatch
            shopt -s globstar
            for pcFile in upstream/**/pkgconfig/*.pc; do
              ${patch-pkg-config hostPkgs} $pcFile $out /clang64
            done
            runHook postPatch
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/
            cp -rt $out upstream/clang64/*
            runHook postInstall
          '';
        });
      in pkgGen {
        inherit targetSystem;
        buildInputs = hostPkgs.lib.mapAttrsToList pkgsFromPacman deps;
        targetSharePath = "../share";
        postInstall = ''
          for item in $buildInputs; do
            cp -t $out/bin $item/bin/*.dll | true # allow deps without dlls
          done
        '';
      };
      packageDeb = hostPkgs: args@{src, ...}: let
        name = src.deb.Package;
        version = src.deb.Version;
      in hostPkgs.stdenvNoCC.mkDerivation {
        name = "${name}-${version}.deb";
        CONTROL = ''
          Package: ${name}
          Version: ${version}
          Section: base
          Priority: optional
          Architecture: ${src.deb.Architecture}
          Depends: ${src.deb.Depends}
          Maintainer: ${hostPkgs.lib.concatStringsSep ", " src.meta.maintainers}
          Description: ${src.meta.description}
        '';
        unpackPhase = ''
          packDir=${name}_${version}
          mkdir -p $packDir/{DEBIAN,usr}
          cp -rt $packDir/usr ${src}/bin | true # allow missing bin
          if [ -e ${src}/share ]; then
            mkdir -p $packDir/usr/share/${name}
            cp -rt $packDir/usr/share/${name} ${src}/share/* 
          fi
        '';
        configurePhase = ''
          printenv CONTROL > ${name}_${version}/DEBIAN/control
        '';
        buildPhase = ''
          ${hostPkgs.dpkg}/bin/dpkg-deb --build ${name}_${version}
        '';
        installPhase = ''
          cp *.deb $out
        '';
      };
      packageWin64Zip = hostPkgs: args@{src, ...}: hostPkgs.stdenvNoCC.mkDerivation {
        name = "${src.name}.zip";
        unpackPhase = ''
          packDir=${src.name}-win64
          mkdir -p $packDir
          cp -rt $packDir ${src}/*
        '';
        buildPhase = ''
          ${hostPkgs.zip}/bin/zip -r $packDir.zip $packDir
        '';
        installPhase = ''
          cp $packDir.zip $out
        '';
      };
    };
  };
}