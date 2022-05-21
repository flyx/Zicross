<p align="center"><img src="/zicross.svg" alt="zicross logo"/></p>
<p align="center">Zicross</p>
<h2 align="center">A <a href="https://nixos.org">Nix</a> toolbox for cross-compilation and foreign packaging, using <a href="https://ziglang.org">Zig</a></h2>

**Zicross** allows you to cross-compile your code into binaries for foreign CPU architectures and operating systems.
It also provides tools for packaging the resulting binary in the target system's format.

The goal of this toolbox is to make it viable to use Nix Flakes as a general build system for your application, while still being able to support packaging for environments outside of the Nix ecosystem (e.g. Windows).
In particular, Zicross helps you with linking against 3rd party libraries available for the target system.
Packaging libraries is currently not an intended use-case.

Zicross uses the **Zig** compiler, which includes `clang` and can thus process C/C++ code, for cross-compiling.
It provides a small build system for *Zig* projects, and additional helper functions for C/C++ and Go are planned.

## Prerequisites

Zicross is a [Nix Flake](https://nixos.wiki/wiki/Flakes), you'll need the [Nix Package Manager](https://nixos.org) and enable the experimental Flakes feature.
You're not required to use NixOS, any OS that runs Nix will do, including macOS and WSL on Windows.

Zicross will fetch all other dependencies automatically via Nix.

## Documentation

**This documentation is rudimentary and not a tutorial.**
Consider having a look at the `examples` folder.

Zicross provides three kinds of functions: *Package collectors*, *builders* and *packagers*.
Package collectors download packages from a foreign package repository (e.g. Debian, MSYS2), make necessary patches to them and supply them as build inputs.
Builders implement the actual compilation of your code and are as configurable as typical build functions from NixPkgs.
Packagers take the output from a builder and generate a package for the target system, e.g. a `.deb` file describing the given dependencies for Debian or a `.zip` file containing the main executable and all required `.dll` files for Windows.

To use Zicross, you need to write a *generator* function like this:

    args@{ buildInputs, targetSystem, ... }: <body>

`targetSystem` is the name of the target system.
`buildInputs` is a list of derivations your application should link to. 
All `args` should be forwarded to the builder you use.

The `body` should use a *builder* function.
Your generator should be given as argument to a *package collector*.

You can define your native, non-cross compiled package by calling the generator yourself.
See the `examples` folder for examples.

### Package Collectors

Every package collector is a function with the following parameters:

    hostPkgs: pkgGen: {
      pkgConfigPrefix ? "/lib/pkgconfig",
      deps ? {},
      targetSystem,
      <others>,
      ...
    }: <impl>

 * `hostPkgs` is a NixPkgs instance for your host system.
 * `pkgGen` is your package generator function, as described above.
 * `pkgConfigPrefix` is the path to `*.pc` files within the packages. Defaults to `/lib/pkgconfig` which is valid for NixOS but other system typically use `/usr/lib/pkgconfig` or similar.
 * `deps` is a set of named dependencies, whose format is defined per collector.
 * `targetSystem` is the name of the target system.
 * `<others>` can be additional attributes that are defined per collector.
 * `...` can be any additional arguments which will be forwarded to your generator.

#### withDebPkgs

Package collector for Debian packages.
`<others>` contain `name` and `version` which must be the desired name and version for the Debian package you wish to create.
`deps` are to have a structure like this:

    {
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
    }

The `packageName` and `minVersion` values are used to generate the `Depends` specification of the resulting package.

#### withMsysPkgs

Package collector for Win64 MSYS2 packages.
Takes no `<others>` values. `deps` are to have a structure like this:

    {
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
    }

`tail` omits the parts that are always the same.
As displayed in `sdl2`, you can add standard `mkDerivation` attributes to manipulate how the package is patched after downloading.
In this case, we remove the `-lSDL2main` flag from the `sdl2.pc` file.

### Builders

Every builder is a function with the following parameters:

    {
      hostPkgs, 
      targetSystem
    }:
    args@{
      buildInputs,
      pkgConfigPrefix ? "/lib/pkgconfig",
      <others>,
      ...
    }: <impl>

The first parameter instantiates the builder for a tuple of host and target system, with the host system given as NixPkgs instance, and the target system given as name.

The second parameter contains standard `mkDerivation` attributes, along with `pkgConfigPrefix` (from your call to the package collector, see above).

#### buildZig

This is the builder for Zig projects.
See [buildZig.nix](/buildZig.nix) for details on its parameters.

This builder autogenerates a `build.zig` file and compiles your project with it.
You specify a list of executables that should be compiled, and the generated `build.zig` file will automatically link them to the given `buildInputs` via `pkg-config`.

The builder is able to handle a dependency tree of zig packages whose documentation is TBD.
See the `examples/zig` folder for an example.

### Packagers

Packagers are functions with the following signature:

    hostPkgs: args@{src, ...}: <impl>

They need an instance of NixPkgs for `hostPkgs`.
The `src` needs to be a derivation generated from a call to a package collector valid for the target system.
For example, `packageDeb` assumes the given derivation has been build with `withDebPkgs`.

#### packageDeb

This packager creates a `.deb` package you can install on Debian.
The dependencies you have given will be specified in the package.
The name and version of the package are the values given to `withDebPkgs`.

#### packageWin64Zip

This packager creates a `.zip` package you can unpack on Windows.
The `.zip` file will contain the compile `.exe` file and all required `.dll` files as defined by the `deps` given to `withMsysPkgs`.

## License

MIT