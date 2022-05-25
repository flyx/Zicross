<p align="center"><img src="/zicross.svg" alt="zicross logo"/></p>
<h1 align="center">Zicross</h1>
<h4 align="center">A <a href="https://nixos.org">Nix</a> toolbox for cross-compilation and foreign packaging, using <a href="https://ziglang.org">Zig</a></h4>

**Zicross** allows you to cross-compile your code into binaries for foreign CPU architectures and operating systems.
It also provides tools for packaging the resulting binary in the target system's format.

The goal of this toolbox is to make it viable to use Nix Flakes as a general build system for your application, while still being able to support packaging for environments outside of the Nix ecosystem (e.g. Windows).
In particular, Zicross helps you with linking against 3rd party libraries available for the target system.
Packaging libraries to be consumed by other applications is currently not an intended use-case.

Zicross uses the **Zig** compiler, which includes `clang` and can thus process C/C++ code, for cross-compiling.
It provides a small build system for *Zig* projects, and additional helper functions for C/C++ and Go are planned.

## Prerequisites

Zicross is a [Nix Flake](https://nixos.wiki/wiki/Flakes), you'll need the [Nix Package Manager](https://nixos.org) and enable the experimental Flakes feature.
You're not required to use NixOS, any OS that runs Nix will do, including macOS and WSL on Windows.

Zicross will fetch all other dependencies automatically via Nix.

## Usage

**This documentation is rudimentary and not a tutorial.**
Consider having a look at the `examples` folder.

Zicross provides two kinds of tools: *Builders* and *Package Translators*.
*Builders* are build functions similar to those already existing in the Nixpkgs ecosystem.
*Package Translators* are functions that take a derivation built with a *Builder* and modify it to build a package for a foreign target system.
*Package Translators* require that the derivation they translate has been built by one of Zicross' *Builders*.

The important property of Zicross **Builders** is that they call `mkDerivation` with an argument named `ZIG_TARGET`.
Translators will take advantage of this by overriding it when cross-compiling.

**Package Translators** are functions that take two arguments:

 * The package `pkg` that is to be translated, which is expected to be an output of `mkDerivation` with overridable attributes `ZIG_TARGET` and `buildInputs` (usually from one of Zicross' *Builders*).
   `ZIG_TARGET` will be used to configure cross-compilation, while `buildInputs` will be used to substitute the native dependencies with ones from the target system.
 * _Arguments_ `args` for the Translator.

The following arguments are accepted by every *Package Translator* inside of `args`:

 * `pkgConfigPrefix` is the path to `*.pc` files within the packages.
   This has a default value defined by the translator, e.g. `/usr/lib/pkgconfig` for the Debian translators.
 * `deps` is a set of named dependencies, whose format is defined per Translator.
   A Translator will download and patch these dependencies, then inject them as `buildInputs` into the `pkg` via `overrideAttrs`.
 * `targetSystem` is the name of the target system in NixOS terms.
 * Every Translator may define additional parameters which might be required.
 * Unknown parameters will be forwarded to the given `pkg`'s `overrideAttrs`.

---

Zicross' tools can be injected independently via several overlays to your Nixpkgs instance.
The following list of overlays assumes you have imported Zicross as `zicross` in your Flake.

### `zicross.overlays.zig`

This overlay provides the package `zig`, which is the current Zig compiler patched to be able to cross-compile code for armhf-based Linux.

The overlay also provides the **builder `buildZig`**:
`buildZig` is a builder for Zig source code.
See [buildZig.nix](/buildZig.nix) for details on its parameters.

This builder autogenerates a `build.zig` file and compiles your project with it.
You specify a list of executables that should be compiled, and the generated `build.zig` file will automatically link them to the given `buildInputs` via `pkg-config`.

The builder is able to handle a dependency tree of zig packages whose documentation is TBD.
See the `examples/zig` folder for an example.

### `zicross.overlays.debian`

This overlay provides the **package translators `buildForDebian`** and **`packageForDebian`**.
See [debian-overlay.nix](/debian-overlay.nix) for details on their parameters.

`buildForDebian` builds the executable for Debian in a derivation with the typical layout (`/bin`, `/share` etc).
Use this if you simply want to create an executable that you can then transfer to your target system.

`packageForDebian` builds a `.deb` package that can be installed on a Debian system.
You need to provide its `name` and `version`, other `.deb` configuration is pulled from the package's `meta` attributes.

### `zicross.overlays.windows`

This overlay provides the **package translators `buildForWindows`** and **`packageForWindows`**.
See [windows-overlay.nix](windows-overlay.nix) for details on their parameters.

`buildForWindows` builds the executable for Windows in a derivation with the typical layout (`/bin`, `/share` etc).
`/bin` contains, besides the executable, also all `.dll` files the executable depends on.

`packageForWindows` packages the structure described above in a simple `zip` file that contains a folder named `<pkg-name>-win64`.
This should be viable as distribution format to Windows users.

Since this overlay uses MSYS2, it currently only supports 64bit Windows.
Building MSYS2 packages is currently not supported.

## License

[MIT](/LICENSE)