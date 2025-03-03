{
  description = "CallScribe";

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
        devShells.default = let
          # Define rustVersion here in the devShell context
          rustVersion = pkgs.rust-bin.stable.latest.default;
        in pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust with IDE components
            (rustVersion.override {
              extensions = [ "rust-src" "clippy" "rustfmt" "rust-analyzer" ];
            })

            # Системные зависимости
            pkg-config
            alsa-lib
          ];

          shellHook = ''
            # Create a special directory structure for Rust Rover
            export RUST_ROVER_HOME="$PWD/.rust-rover"
            mkdir -p $RUST_ROVER_HOME/bin

            # Create symbolic links to Rust components
            for cmd in rustc cargo rustfmt clippy rust-analyzer; do
              if command -v $cmd &> /dev/null; then
                ln -sf $(command -v $cmd) $RUST_ROVER_HOME/bin/$cmd
              fi
            done

            # Export the path to the Rust standard library sources
            export RUST_SRC_PATH="${rustVersion}/lib/rustlib/src/rust/library"

            echo ""
            echo "Rust Rover environment configured in $RUST_ROVER_HOME"
            echo "In Rust Rover settings, specify the path: $RUST_ROVER_HOME/bin"
            echo "In Rust Rover settings, specify RUST_SRC_PATH: $RUST_SRC_PATH"
            echo ""

            # Cleaning when leaving the shell
            trap "rm -rf $RUST_ROVER_HOME" EXIT
          '';
        };
      }
    );
}
