{
  description = "Call scribe project";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      let
        inherit (pkgs) stdenv lib;
        isLinux = stdenv.isLinux;
        isDarwin = stdenv.isDarwin;

        # Linux-specific dependencies for Slint UI (X11/Wayland)
        linuxDeps = with pkgs; lib.optionals isLinux [
          wayland
          libxkbcommon
          libGL
          xorg.libX11
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
        ];

        # macOS-specific dependencies
        # Note: Apple frameworks are linked automatically by Cargo on macOS
        darwinDeps = with pkgs; lib.optionals isDarwin [
          libiconv  # Required for some Rust crates on macOS
        ];
      in
      {
        devShells.default = with pkgs; mkShell {
          buildInputs = [
            openssl
            pkg-config
            (rust-bin.beta.latest.default.override {
              extensions = [ "rust-analyzer" "rust-src" ];
            })

            # Fonts
            fontconfig
            freetype

            # Skia build dependencies
            clang
            python3
            ninja

            # Nix LSP
            nixd

            # Serena MCP dependencies
            uv

            # MCP servers (Context7, GitHub)
            nodejs_22
          ] ++ linuxDeps ++ darwinDeps;

          nativeBuildInputs = [
            clang
          ];

          # LD_LIBRARY_PATH only needed on Linux
          LD_LIBRARY_PATH = lib.optionalString isLinux (lib.makeLibraryPath ([
            libGL
            fontconfig
            freetype
          ] ++ linuxDeps));

          # Use system fontconfig on Linux (inherits your system font settings)
          FONTCONFIG_FILE = lib.optionalString isLinux "/etc/fonts/fonts.conf";

          # For Skia/bindgen
          LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

          shellHook = ''
            source ./scripts/dev-setup.sh
          '';
        };
      }
    );
}
