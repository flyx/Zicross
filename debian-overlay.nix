self: super: {
  buildForDebian =
    # the original package to override
    pkg:
    # debian package's name
    { name
    # debian package's verison
    , version
    # where to find *.pc files in the given debian packages.
    , pkgConfigPrefix ? "/usr/lib/pkgconfig"
    # set of debian packages to download, patch and put into buildInputs
    , deps ? {}
    # name of the target system (in NixOS terminology)
    , targetSystem}:
    
    let
      patch-pkg-config = import ./patch-pkg-config.nix;
      fetchDeb = {path, sha256, ...}: builtins.fetchurl {
        url = "http://deb.debian.org/${path}";
        inherit sha256;
      };
      pkgFromDebs = name: input: let
        hasDev = builtins.hasAttr "dev" input;
        srcs = [ (fetchDeb input)] ++
          (if hasDev then [ (fetchDeb input.dev) ] else []);
      in super.stdenvNoCC.mkDerivation {
        name = "dpkg-${name}";
        inherit srcs;
        phases = ["unpackPhase" "patchPhase" "installPhase"];
        unpackPhase = ''
          mkdir -p upstream
          ${super.dpkg}/bin/dpkg-deb -x ${builtins.elemAt srcs 0} upstream
        '' + (if hasDev then ''
          ${super.dpkg}/bin/dpkg-deb -x ${builtins.elemAt srcs 1} upstream
        '' else "");
        patchPhase = ''
          shopt -s globstar
          for pcFile in upstream/**/pkgconfig/*.pc; do
            ${patch-pkg-config super} $pcFile $out
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
    in pkg.overrideAttrs (_: {
      inherit pkgConfigPrefix;
      ZIG_TARGET = super.zig.systemName.${targetSystem};
      buildInputs = super.lib.mapAttrsToList pkgFromDebs deps;
      passthru.deb = {
        Package = name;
        Version = version;
        Architecture = debianArch.${targetSystem};
        Depends = super.lib.concatStringsSep ", " (
          super.lib.mapAttrsToList (key: value: "${value.packageName} (>= ${value.minVersion})") deps
        );
      };
      targetSharePath = "/usr/share/${name}";
    });
  packageForDebian = 
    # the original package to override
    pkg:
    # debian package's name
    { name
    # debian package's verison
    , version
    # where to find *.pc files in the given debian packages.
    , pkgConfigPrefix ? "/usr/lib/pkgconfig"
    # set of debian packages to download, patch and put into buildInputs
    , deps ? {}
    # name of the target system (in NixOS terminology)
    , targetSystem}@args':
    
    let
      name = src.deb.Package;
      version = src.deb.Version;
      src = self.buildForDebian pkg args';
    in super.stdenvNoCC.mkDerivation {
      name = "${name}-${version}.deb";
      CONTROL = ''
        Package: ${name}
        Version: ${version}
        Section: base
        Priority: optional
        Architecture: ${src.deb.Architecture}
        Depends: ${src.deb.Depends}
        Maintainer: ${super.lib.concatStringsSep ", " src.meta.maintainers}
        Description: ${src.meta.description}
      '';
      unpackPhase = ''
        packDir=${name}_${version}
        mkdir -p $packDir/{DEBIAN,usr}
        cp -rt $packDir/usr --no-preserve=mode ${src}/bin | true # allow missing bin
        if [ -e ${src}/share ]; then
          mkdir -p $packDir/usr/share/${name}
          cp -rt $packDir/usr/share/${name} --no-preserve=mode ${src}/share/* 
        fi
      '';
      configurePhase = ''
        printenv CONTROL > ${name}_${version}/DEBIAN/control
      '';
      buildPhase = ''
        ${super.dpkg}/bin/dpkg-deb --build ${name}_${version}
      '';
      installPhase = ''
        cp *.deb $out
      '';
    };
}