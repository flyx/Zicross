<p align="center"><img src="/zicross.svg" alt="zicross logo"/></p>
<p align="center">Zicross</p>
<h2 align="center">A <a href="https://nixos.org">Nix</a> toolbox for cross-compilation and foreign packaging, using <a href="https://ziglang.org">Zig</a></h2>

<h1>This Readme is preliminary, nothing actually works yet</h1>

**Zicross** allows you to cross-compile your code into binaries for foreign CPU architectures and operating systems.
It also provides tools for packaging the resulting binary in the target system's format.
Currently, the following packagers are available:

 * _debian_, for Debian-based systems (creates a `.deb` package)
 * _zipped_, for Windows (creates a `.zip` file containing the binary and all required DLLs)
 
Zicross supports C/C++, Go with C dependencies, and not surprisingly, Zig.

## Prerequisites

Zicross is a [Nix Flake](https://nixos.wiki/wiki/Flakes), you'll need the [Nix Package Manager](https://nixos.org) and enable the experimental Flakes feature.
You're not required to use NixOS, any OS that runs Nix will do, including macOS and WSL on Windows.

Zicross will fetch all other dependencies automatically via Nix.

## How to use

TODO, see `examples` folder for examples.

## License

MIT