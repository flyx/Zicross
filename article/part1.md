---
layout: default
title: "Cross-Compiling and packaging C, Go and Zig projects with Nix"
part: 1
parttitle: C
kind: article
permalink: /cross-packaging/part1/
weight: 11
---

The C source code we're gonna compile is [available at GitHub][7] and not reproduced here for brevity.

## Setting up the Build System

Let's have a trivial Makefile:

{% highlight Makefile %}
{% include_relative examples/c/Makefile %}
{% endhighlight %}

As you can see, we're simply telling the system's C compiler `CC` to compile our source file `main.c` to an object file `main.o` and then link it into an executable `zicross_demo_c`.
We're relying on the variables `CFLAGS` and `LDFLAGS` to provide the necessary arguments to specify our target architecture/system and link against SDL.

In the source code, we're also including `resources.h`, a header that doesn't exist.
This will provide the constant `resources_data` which will be the path to our resource files.
In this case, we want to bundle the resource file `logo.txt` which contains the [Zicross logo in ASCII-art][8].

To generate `resources.h`, inject the necessary `CFLAGS` and `LDFLAGS`, and provide the resource file, we'll need a build system.
We're going to use [Nix Flakes][9], for which Zicross has been written, so you need the `nix` utility installed with the experimental `flakes` feature enabled.
You can instead follow the article's descriptions and adopt them for whatever build system you prefer.

{% capture flake_src %}
{% include_relative examples/c/flake.nix %}
{% endcapture %}

{% assign flake = flake_src | newline_to_br | split: "<br />" %}

Let's write a `flake.nix`:

{% highlight nix %}
{{ flake | slice: 0, 47 | join: ""}}
    };
  };
}
{% endhighlight %}

We're building our `pkgs` from Nixpkgs with `zicross.overlays.zig`, which provides us with the Zig compiler.
We'll be needing `zicross.overlays.debian` and `zicross.overlays.windows` later on for cross-compiling.
`pkgs.zigStdenv` is an stdenv that uses Zig as C compiler by setting up `CC` appropriately.
Generally, this is the `CC` script:

    #!/bin/bash
    ADDITIONAL_FLAGS=
    if ! [ -z ''${ZIG_TARGET+x} ]; then
      ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS -target $ZIG_TARGET"
    fi
    zig cc $ADDITIONAL_FLAGS $@

So what we do is to check whether the variable `ZIG_TARGET` is set and if so, hand it over to the compiler via `-target`.
This is our hook to do cross-compiling.
The actual script does some additional Nix-specific things and can be inspected [here][10].

Back to our flake:
Our `buildInputs` are `SDL2` and `libiconv`, a dependency of `SDL2` on some systems.
We give `DESTDIR` in `makeFlags` to tell Make to write the result into the `out` directory, the default target directory for Nix derivations.

`targetSharePath` is a path into the `share` subdirectory of `out`, where we will put our logo file.
This expands to an absolute path into the Nix store (let's remember that for later when we cross-package and need to set this up differently).
In `postConfigure`, we write our `resources.h` file and build the path to the logo file based on `targetSharePath`.

In `preBuild`, we use `pkg-config` to set up our `CFLAGS` and `LDFLAGS` for linking against SDL2.
Finally, in `preInstall`, we copy the logo file to the `share` subdirectory.
Now, we can natively build and run our application via

    $ nix build .#demo
    $ result/bin/zicross_demo_c

## Cross-Compiling for Debian on Raspberry Pi

Now that we can compile natively, let's cross-compile the application for Debian on a Raspberry Pi.
To do that, add the following package in `flake.nix`:

{% highlight nix %}
{{ flake | slice: 47, 25 | join: ""}}
{% endhighlight %}

We call `packageForDebian`, a function provided by Zicross, on our `demo` derivation, and supply some additional information.
For people not familiar with Nix, `demo` is a *description* of how a package is built, and `packageForDebian` can produce a modified description based on this one, which can then be evaluated to build a different package.

Let's discuss the information we provide:

 * `targetSystem` is the triplet of the target system, in Nix terminology.
   Clang will need `-target arm-linux-gnueabihf` while Debian will need `Architecture = armhf;`, both of which will be derived from the given `targetSystem` by Zicross.
 * `pkgConfigPrefix` specifies where to find `pkg-config` configuration files.
   This path is interpreted in the context of the packages we depend on, i.e. while being an absolute path, the root will be the unpacked dependency.
   By default, this path would be `/usr/lib/pkgconfig` but it's different for ARM-based Debian, hence we set it explicitly.
 * `includeDirs` work like `pkgConfigPrefix`, and default to `[ "/usr/include" ]` but again, ARM-based Debian differs so we give the additional directory.
 * `name` is the name of the Debian package we're gonna build. No underscores are allowed here.
 * `deps` is the interesting part:
   These are the Debian packages we depend on.
   Each package gives a `path` into the Debian repository under `http://deb.debian.org/`, and a base32-encoded sha256 hash.
   We can add a related development package as `dev`.
   You can generate the base32 hash from the hex-encoded hash, e.g. [from here][11], by doing

   {% highlight plain %}
   $ nix-hash --type sha256 --to-base32 <hex input>
   {% endhighlight %}

Zicross will download the specified packages.
In their original state, they are not usable because their pkg-config descriptions assume they are unpacked into the system root.
But we're certainly not putting them into the host's `/usr`.
Zicross will put them into the Nix store, but you can put them anywhere.
The important thing is that we need to patch the `*.pc` files so that they point to the directory we unpacked into.
For example, these are the first lines of the original `/usr/lib/arm-linux-gnueabihf/pkgconfig/sdl2.pc` file:

{% highlight plain %}
# sdl pkg-config source file

prefix=/usr
exec_prefix=${prefix}
libdir=${prefix}/lib/arm-linux-gnueabihf
includedir=${prefix}/include
{% endhighlight %}

Since it is neatly organized, we only need to change the `prefix=/usr` line to point to wherever we unpacked the package.
Zicross uses [a shellscript][12] for this, resulting in:

{% highlight plain %}
# sdl pkg-config source file

prefix=/nix/store/j11idzdglij4maxaz7jw0f2z2wd49wb2-dpkg-sdl2/usr
exec_prefix=${prefix}
libdir=${prefix}/lib/arm-linux-gnueabihf
includedir=${prefix}/include
{% endhighlight %}

`pkg-config` actually has the capability to do

{% highlight plain %}
$ pkg-config --define-variable=prefix=<store-path>/usr …
{% endhighlight %}

which overrides the given `prefix`.
However, this wouldn't be transparent to the build system anymore, as we'd need a different `pkg-config` invocation for each dependency.
This is why we go with modifying the `.pc` files instead.

There is also a `PKG_CONFIG_SYSROOT_DIR` variable we could set.
Zicross makes each dependency into a standalone derivation (so it can be re-used), hence we do not have a single sysroot, which makes `PKG_CONFIG_SYSROOT_DIR` ill-equipped for our purposes.

Now we need to set up `pkg-config` to consume our `.pc` files *instead of the ones of the host system*.
We do not want to link against any native libraries that might be available on the host.
For this, we must append the directories containing `.pc` files to `PKG_CONFIG_PATH`.
Zicross does this automatically by replacing the original `buildInputs` with the provided `deps`.
As long as all packages queried are in `PKG_CONFIG_PATH`, `pkg-config` will not search the host system's packages.

Let us now cross-compile our application:

{% highlight plain %}
$ nix build .#rpiDeb
$ readlink result
/nix/store/g7mync647ilrcm8xqa510rlvfmlikyxq-zicross-demo-c-0.1.0.deb
{% endhighlight %}

So besides cross-compiling, Zicross also packaged our application.
What it did was to use the meta information on the package to write a Debian `control` file, and then package the compiled binary with `dpkg` ([see this derivation][13]).
Let's see what it looks like:

    $ dpkg -I result
     new Debian package, version 2.0.
     size 3756 bytes: control archive=280 bytes.
         233 bytes,     9 lines      control              
     Package: zicross-demo-c
     Version: 0.1.0
     Section: base
     Priority: optional
     Architecture: armhf
     Depends: libcrypt1 (>= 1:4.4.18), libsdl2-2.0-0 (>= 2.0.0)
     Maintainer: Felix Krause <contact@flyx.org>
     Description: Zicross Demo App (in C)

Note how `libcrypt` was not in the dependencies specified by our build script, we only added this for cross-compiling.
The dependencies have minimal versions specified as given in `flake.nix`.
As long as there are no API breaks, this package works with any newer version of `libsdl2` and does not require the version we used for linking.

You can now copy this `.deb` package to a Debian on a Raspberry Pi and install it via

    $ sudo apt install ./zicross-demo-c-0.1.0.deb

Currently, Zicross does not implement signing of the package so it is only useful locally.

## Cross-Compiling for x86_64 Windows

Unlike Debian, Windows does not have a primary, default package manager.
Usually, Windows applications are spread via an installer or just a `.zip` file which contains the application and all its dependencies.
Zicross allows us to build the latter.

Thankfully, [MSYS2][14] provides pacman-based repositories with packages that provide `.pc` files for `pkg-config`.
We'll be using the `clang64` repository to query dependencies, similarly to what we did for Debian.

This is what we'll add to our Flake's packages:

{% highlight nix %}
{{ flake | slice: 72, 28 | join: "" }}
{% endhighlight %}

Somewhat similar to what we did before, with some differences:

 * `appendExe` instructs Zicross to add the `.exe` file extension to the binary file `zicross_demo_c`.
   Our Makefile creates it without that extension, and we want to have it for Windows.
 * The `sdl2` dependency has a `postPatch` section.
   This is a workaround for a [Zig issue][15] that causes `zig cc` to not link against static libraries.
   We mitigate this by, instead of doing `-lSDL2main`, adding the `.a` file as positional argument.
   This is patched into our `sdl2.pc` file.
 * We have more dependencies.
   This is because for Windows, we want to package all `.dll` files of all transitive dependencies.
   To be able to do this, we must download those dependencies.
   For Debian, we only needed to download those libraries we explicitly link against, because any transitive dependencies are handled by the package manager.

Let's build it:

{% highlight plain %}
$ nix build .#win64Zip
$ unzip -Z1 result # list content
zicross_demo_c-0.1.0-win64/
zicross_demo_c-0.1.0-win64/bin/
zicross_demo_c-0.1.0-win64/bin/libcharset-1.dll
zicross_demo_c-0.1.0-win64/bin/libc++.dll
zicross_demo_c-0.1.0-win64/bin/libiconv-2.dll
zicross_demo_c-0.1.0-win64/bin/zicross_demo_c.exe
zicross_demo_c-0.1.0-win64/bin/libvulkan-1.dll
zicross_demo_c-0.1.0-win64/bin/SDL2.dll
zicross_demo_c-0.1.0-win64/bin/libunwind.dll
zicross_demo_c-0.1.0-win64/share/
zicross_demo_c-0.1.0-win64/share/logo.txt
{% endhighlight %}

Since we bundle the `.dll` files with our application, we need to keep the dependencies up-to-date – unlike with Debian, where we need the library files only for linking and then let the package manager fetch the actually used versions on the target system.

## Resource Files

What we didn't discuss yet is how the resource path is handled.
Zicross automatically overrides `targetSharePath` when cross-compiling, and puts the `share` files there:
When targeting Debian, the path will become `/usr/share/<name>` where `<name>` is the name of the Debian package.
When targeting Windows, the path will become `../share`, which works because the working directory of an `.exe` file, when run via double-click, is the file's parent directory.

So what happens is that the path to our `share` folder is hardcoded into our binary, and is an absolute path for native Nix compiling and Debian cross-compiling, but a relative path for Windows cross-compiling.

## Conclusion

With some modifications in the right places, we can consume `pkg-config` configuration from foreign package repositories to cross-compile our code.
Due to the consistency of `pkg-config` configurations, this can be automated, which is what Zicross does, among other things.
Lots of tools use `pkg-config`, so this is a good foundation for more complex projects.
For example, CMake allows you to use `pkg-config` to search for your dependencies.

In the next part, we will apply this knowledge to Go projects.

 [7]: https://github.com/flyx/Zicross/blob/master/examples/c/main.c
 [8]: https://github.com/flyx/Zicross/blob/master/logo_matrix.txt
 [9]: https://nixos.wiki/wiki/Flakes
 [10]: https://github.com/flyx/Zicross/blob/master/zig-overlay.nix#L25
 [11]: nix-hash --type sha256 --to-base32
 [12]: https://github.com/flyx/Zicross/blob/master/patch-pkg-config.nix
 [13]: https://github.com/flyx/Zicross/blob/master/debian-overlay.nix#L90
 [14]: https://packages.msys2.org/repos
 [15]: https://github.com/ziglang/zig/issues/4986