<p align="center"><img src="/zicross.svg" alt="zicross logo"/></p>
<h1 align="center">Zicross</h1>
<h4 align="center">A <a href="https://nixos.org">Nix</a> toolbox for cross-compilation and foreign packaging, using <a href="https://ziglang.org">Zig</a></h4>

**Zicross** is a build system for [Nix Flakes](https://nixos.wiki/wiki/Flakes).
It allows you to cross-compile your C, Go or Zig code for foreign CPU architectures and operating systems.
It also provides tools for packaging the resulting binary in the target system's format.

The goal of this toolbox is to make it viable to use Nix Flakes as a general build system for your application, while still being able to target environments outside of the Nix ecosystem (e.g. Windows).
In particular, Zicross helps you with linking against 3rd party libraries available for the target system.

Zicross uses the **Zig** compiler, which includes `clang` and can thus process C/C++ code, for cross-compiling.
It provides a small build system for *Zig* projects, as well as support scripts for *C* and *Go* projects.
*Go* projects need Zicross only when they depend on *C* libraries, since pure Go is able to cross-compile without any help from *Zig*.

**This is pre-alpha software**.
Use at your own risk.
Will likely fail when doing anything complex.
Feel free to report problems.

## Prerequisites

Zicross is a [Nix Flake](https://nixos.wiki/wiki/Flakes), you'll need the [Nix Package Manager](https://nixos.org) and enable the experimental Flakes feature.
You're not required to use NixOS, any Nix-capable host will do, including macOS and WSL on Windows.

Zicross will fetch all other dependencies automatically via Nix.

## Usage

Familiarity with Nix Flakes is assumed.
This documentation is very rudimentary, check the `examples` folder for examples.
It contains Flakes for each of the languages *C*, *Go* and *Zig*.
To demonstrate third-party dependencies, the code renders Zicross' logo into a window via `SDL2`.
All flakes can compile natively, to Windows, and to a Raspberry Pi running Debian.

Generally, you write a derivation that builds your code natively.
Your Flake should inject `overlays.zig` and, if you're writing *Go*, also `overlays.go` (which depends on the former).
Use `zigStdenv` for a derivation building a *C* project.
`buildGoModule` injected by `overlays.go` is to be used for *Go* projects.
`buildZig` is for *Zig* projects.
You provide third-party libraries via `buildInputs` as usual.

For each supported target system, an overlay is available that provides functions to package for that system.
Currently available are `overlays.debian` and `overlays.windows`.
These will give you `buildForDebian`, `packageForDebian`, `buildForWindows`, and `packageForWindows`.
Each of those functions takes your base package as first argument, and a configuration set as second argument.
The package you provide as first argument must have been defined as described above.

The foreign builders require a set of `deps`, which are dependencies that are to be fetched from the target system's package repository (MSYS2 for Windows).
You must specify some meta information, including the name and hash of the package, and the builder will fetch and process the packages and then *replace the original `buildInputs`* with those packages.
The builders also do some additional tweaking that is required.

The output of packaging functions depends on the target system.
For example, `packageForDebian` will output a `.deb` file that can be installed as package into the target Debian system.
The package metadata describes its dependencies based on the `deps` you provided.

The `packageForWindows` function will instead output a `.zip` file that contains the executable and *all required DLL dependencies*.
This is for simple consumption by the end-user, who likely isn't familiar with MSYS2.
**Important:** This means that when building for Windows, it is your responsibility to update dependencies.
When building for Debian, it is not, since the dependencies can be updated independently from your package.

`buildZig` has been specifically designed to be a drop-in for Zig's native build system, and actually creates a `build.zig` to compile your code.
The advantage of `buildZig` is that you can depend on third-party libraries by simply fetching them from GitHub (or somewhere else) – Zig currently has no official package manager.
You can also use it to manage non-Zig dependencies, like C libraries.

## Developer Documentation

The `zig` package defined in `overlays.zig` contains a `/bin/cc` wrapper script, which can be used as `CC` drop-in and will call `zig cc`.
It looks for an env variable `ZIG_TARGET` and if found, configures `zig` to cross-compile.
This is used directly for *C* projects, and indirectly in *Go* projects which will use the wrapper via *CGO* (which processes C dependencies of your Go code).

The foreign builder functions inject a `ZIG_TARGET` value into the given derivation to facilitate cross-compilation.
The other thing they do is to patch `*.pc` files in the given `deps` so that they can be used within the build script even though they were not written for Nix.
`pkg-config` is assumed to be used for looking up dependencies.

## License

[MIT](/LICENSE)