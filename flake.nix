{
  description = "CallScribe";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = nixpkgs.legacyPackages;
    in {
      packages = forAllSystems (system: {
        default = pkgsFor.${system}.callPackage ./. { };
      });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor.${system};
          rustToolchain = with pkgs; [
            cargo
            rustc
            rustfmt
            rust-analyzer
            clippy
          ];
        in {
          default = pkgs.mkShell {
            buildInputs = rustToolchain ++ (with pkgs; [
              # Add any other packages you need here
            ]);

            shellHook = ''
              # Create a temporary directory to simulate the Rust toolchain structure
              export RUST_FAKE_HOME="$PWD/.rust-toolchain-for-IDE"
              mkdir -p $RUST_FAKE_HOME/bin

              # Create symbolic links for Rust components
              for cmd in cargo rustc rustfmt rust-analyzer clippy; do
                if command -v $cmd &> /dev/null; then
                  ln -sf $(command -v $cmd) $RUST_FAKE_HOME/bin/$cmd
                fi
              done

              # Export an environment variable so we know where our fake toolchain is located
              export RUST_ROVER_TOOLCHAIN="$RUST_FAKE_HOME"

              echo ""
              echo "Rust toolchain for the IDE is configured in $RUST_FAKE_HOME"
              echo "Use this path in the Rust Rover settings: $RUST_FAKE_HOME/bin"
              echo ""

              # Очистка при выходе из оболочки
              trap "rm -rf $RUST_FAKE_HOME" EXIT
            '';
          };
        }
      );
    };
}
