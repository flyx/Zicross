---
layout: default
title: "Cross-Compiling and packaging C, Go and Zig projects with Nix"
part: 2
parttitle: Go
kind: article
permalink: /cross-packaging/part2/
weight: 12
---

The [Go source][1] we want to compile is functionally equivalent to the C source.

## Setting up the Build System

For Go, we'll want a `go.mod` file that defines our project's Go dependencies:

{% highlight go %}
module github.com/flyx/Zicross/examples/go

go 1.18

require github.com/veandco/go-sdl2 v0.4.25
{% endhighlight %}

We'll also need a corresponding `go.sum`, which can be created via `go mod tidy`.
Now let's look how the `go-sdl2` wrapper [links to SDL2][2]:

{% highlight go %}
//#cgo windows LDFLAGS: -lSDL2
//#cgo linux freebsd darwin openbsd pkg-config: sdl2
import "C"
{% endhighlight %}

`pkg-config`, how convenient – we've already set that up.
Except for Windows, we'll handle that later.

To compile natively, we only need to ensure that `SDL2` is available via `pkg-config`.

{% capture flake_src %}
{% include_relative examples/go/flake.nix %}
{% endcapture %}

{% assign flake = flake_src | newline_to_br | split: "<br />" %}

Let's write a `flake.nix` that compiles our code:

{% highlight nix %}
{{ flake | slice: 0, 63 | join: "" }}
    };
  };
}
{% endhighlight %}

This is pretty similar to what we did for C.
The additional overlay `zicross.overlays.go` overrides the standard `pkgs.buildGoModule` with a version that uses Zig as C compiler.

The `mySDL2` package is a workaround for macOS.
Since `go-sdl2` links to much more parts of SDL2 than our C source did, we can run into an error since X11 is by default enabled for macOS in Nixpkgs.
We create a modified SDL2 package that has X11 disabled to avoid this error.

The `vendorSha256` is something Nix needs to ensure that the Go dependencies, specified in `go.mod`, are what it expects them to be.
Initially, you can give `pkgs.lib.fakeSha256` to get an error message that tells you what the actual checksum is, and then substitute that.

Don't mind the `postUnpack` workaround, this mitigates a problem arising from the sources being located in the directory `examples/go`.
`buildGoModule` dislikes the base directory being named `go` which is what the workaround fixes.

Now with this in place, we can compile our Go application natively and test it:

{% highlight plain %}
$ nix build .#demo
$ result/bin/zicross_demo_go
{% endhighlight %}

## Cross-Compiling for Debian on Raspberry Pi

Like before, let's add an additional package that builds a `.deb` file:

{% highlight nix %}
{{ flake | slice: 63, 36 | join: "" }}
{% endhighlight %}

We're using `packageForDebian` just like we did for C.
As we know, this configures our `zig cc` compiler.
However we *also* need to configure the Go compiler for cross-compiling, and we do that via `overrideAttrs` – we need to set `GOOS` and `GOARCH` to the correct values for the target system.

Since `go-sdl2` includes significantly more SDL2 headers than our C code did, we need to add additional dependencies that provide header files that are included by some of the SDL2 headers – these are transitive dependencies of `libsdl2-dev`.
They don't have a `packageName` since we don't want to add them as dependencies of the created package.

Everything else looks similar to what we did for C.
Now let's test it:

{% highlight plain %}
$ nix build .#rpiDeb
$ dpkg -I
 new Debian package, version 2.0.
 size 470990 bytes: control archive=281 bytes.
     235 bytes,     9 lines      control              
 Package: zicross-demo-go
 Version: 0.1.0
 Section: base
 Priority: optional
 Architecture: armhf
 Depends: libcrypt1 (>= 1:4.4.18), libsdl2-2.0-0 (>= 2.0.0)
 Maintainer: Felix Krause <contact@flyx.org>
 Description: Zicross Demo App (in Go)
 {% endhighlight %}

Looks good.

## Cross-Compiling for x86_64 Windows

Remember how `go-sdl2` doesn't use `pkg-config` when compiling for Windows?
There are two ways we can remedy this:

 * We can patch `go-sdl2`.
   This is possible during the vendoring phase which downloads all dependencies.
 * We can manually add the flags provided by `pkg-config` to `CGO_LDFLAGS`

We will go for the latter option since it is less intrusive.
Here's our package:

{% highlight nix %}
{{ flake | slice: 99, 35 | join: ""}}
{% endhighlight %}

As before, we set `GOOS` and `GOARCH` appropriately.
As discussed, we add the `pkg-config` libs in `postConfigure`.
The libraries we link are the same as for C.

Let's build and check the result:

{% highlight plain %}
$ nix build .#win64Zip
$ unzip -Z1 result
zicross_demo_go-0.1.0-win64/
zicross_demo_go-0.1.0-win64/bin/
zicross_demo_go-0.1.0-win64/bin/libcharset-1.dll
zicross_demo_go-0.1.0-win64/bin/libc++.dll
zicross_demo_go-0.1.0-win64/bin/libiconv-2.dll
zicross_demo_go-0.1.0-win64/bin/libvulkan-1.dll
zicross_demo_go-0.1.0-win64/bin/SDL2.dll
zicross_demo_go-0.1.0-win64/bin/libunwind.dll
zicross_demo_go-0.1.0-win64/bin/zicross_demo_go.exe
zicross_demo_go-0.1.0-win64/share/
zicross_demo_go-0.1.0-win64/share/logo.txt
{% endhighlight %}

## Conclusion

The `pkg-config` setup for C works quite well for Go.
The only additional thing needed is setting up the Go compiler for cross-compiling.
There are some quirks, but generally it works quite well.

 [1]: https://github.com/flyx/Zicross/blob/master/examples/go
 [2]: https://github.com/veandco/go-sdl2/blob/v0.4.25/sdl/sdl_cgo.go#L6