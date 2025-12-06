{
  description = "Call scribe project";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      {
        devShells.default = with pkgs; mkShell {
          buildInputs = [
            openssl
            pkg-config
            rust-bin.beta.latest.default

            # Slint UI dependencies
            wayland
            libxkbcommon
            libGL
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr

            # Fonts
            fontconfig
            freetype

            # Skia build dependencies
            clang
            python3
          ];

          nativeBuildInputs = [
            clang
          ];

          LD_LIBRARY_PATH = lib.makeLibraryPath [
            wayland
            libxkbcommon
            libGL
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr
            fontconfig
            freetype
          ];

          # Use system fontconfig (inherits your system font settings)
          FONTCONFIG_FILE = "/etc/fonts/fonts.conf";

          # For Skia/bindgen
          LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
        };
      }
    );
}
