---
layout: default
title: "Cross-Compiling and packaging C, Go and Zig projects with Nix"
title_short: Cross-Packaging C/Go/Zig
kind: article
permalink: /cross-packaging/
weight: 10
date: 2022-09-16
has_parts: true
---

This article shows how you can cross-compile C, Go or Zig code and build a package in the target system's native format – so for example, a `.deb` package for Debian Linux, or a `.zip` package containing your application and all dependencies for Windows.
The focus is on linking to C-level dependencies provided by the target system, so that you do not need to cross-compile those dependencies.

There are a variety of use-cases for this.
Maybe you want to build an application for a Raspberry Pi with an ARM CPU, on a x86_64 Linux host because compiling on the RaspPi is slow.
Maybe you want to package your application for Windows on macOS but don't want to set up a Windows host.
Maybe you want to use Nix Flakes as a build system, but do not want to limit your application to the Nix ecosystem.

This article heavily features [Zicross][1], a build system for [Nix][2] I have written that automates most things.
I will describe what Zicross invocations do so that you can apply this knowledge without having to depend on Nix.
You will find all source code discussed here in the [Zicross examples directory][3].

We will package an application that uses [SDL][4] to render the Zicross logo in a window.
This is to show how we can link to a C library (SDL) and how we can package resource files (the logo).
The application is implemented in C, Go and Zig and we will discuss the details for each language.

We will be cross-compiling for Debian (armv7) on Raspberry Pi, and Windows.
The Raspberry Pi has been chosen since it is a device you usually want to cross-compile for, due to its limited resources.
Windows has been chosen because Nix does not support it natively, and so cross-compiling is the only option for supporting it.

 * **[Part 1: C](part1/)**
 
   This part will introduce Zicross and will discuss how we need to prepare C dependencies for cross-compiling.
   We will cross-compile C code but won't go much into C-specific details.
   This lays the foundation for the following parts.

 * **[Part 2: Go](part2/)**
 
   Pure Go code can be cross-compiled directly by the Go compiler, but for Go code that links to C, we need a C cross-compiler.
   This part describes how we can apply what we learned previously to Go.

 * **[Part 3: Zig](part3/)**
 
   This part is independent from part 2.
   It introduces the Zig build system provided by Zicross.
   Since Zig does not have an official package manager, we will also discuss how Zicross can be used as one.
   Of course we will again discuss cross-compiling.

We'll be using [Zig][5] as cross-compiler for C.
Zig includes [clang][6], which is natively a cross-compiler.
It also includes C stdlib headers for the platforms it targets.
In sum, it provides us with everything to get started.

 [1]: https://github.com/flyx/Zicross
 [2]: https://nixos.org
 [3]: https://github.com/flyx/Zicross/tree/master/examples
 [4]: http://www.libsdl.org
 [5]: https://ziglang.org
 [6]: https://clang.llvm.org