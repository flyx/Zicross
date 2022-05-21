# Example: Zig Project

This demo application creates a window via SDL and displays the Zicross logo in it.
It is implemented in Zig.

You can build the following packages here:

---

    nix build .

Builds the application for your current system.
Run it afterwards via

    result/bin/zicross_demo_zig

---

    nix build .#rpiDeb

Build and packages the application for Armbian on a Raspberry Pi 4.
May work on other versions of the board (I don't know the details).

Copy the `result` to your RPi and do

    sudo apt install zicross_demo_zig-0.1.0.deb

Afterwards you should be able to run

    zicross_demo_zig

---

    nix build .#win64Zip

Builds and packages the application for x86_64 Windows.
Copy the resulting `.zip` file to a Windows installation, unpack and run the `.exe`.