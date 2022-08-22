# Zig nightly & release binaries

This directory was originally at `github:roarkanize/zig-overlay`, which mysteriously vanished.
It isn't updated regularly here but it's better than nothing.
I can't really maintain it unless I put some initial effort into it by rewriting the update script, as I don't know Ruby.
This will probably not happen any time soon.

## Original Description

In this repository lives a Nix flake packaging the *Zig* compiler binaries using the [data](https://ziglang.org/download/index.json) provided by the Zig team.

### Provided utilities

 - *Nightly* versions – not updated daily anymore – (`.master.<date>`), starting from version `0.8.0-dev.1140+9270aae07` dated 2021-02-13, and latest master (`.master.latest`) for the sake of convenience.
 - Release versions.

### Usage

Obsolete, since this is not a standalone Flake anymore.

### For contributors

The `update` script manages updating the information in `sources.json`. The only dependency is Nix, and it's written internally in Ruby.
