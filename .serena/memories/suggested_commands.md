# Suggested Commands for Development

## Environment Setup
```bash
# Enter development environment (required before any development)
nix develop

# This automatically:
# - Sets up Rust toolchain with rust-analyzer
# - Configures LSP paths for Zed editor
# - Installs slint-lsp if missing
```

## Build & Run
```bash
# Build the project
cargo build

# Run the application
cargo run

# Build for release
cargo build --release
```

## Code Quality
```bash
# Check code without building
cargo check

# Run clippy linter
cargo clippy

# Format code
cargo fmt

# Run tests
cargo test
```

## Git Workflow
```bash
# Check status
git status

# Create branch
git checkout -b feature-name

# Commit
git add -A && git commit -m "message"

# Push and create PR
git push -u origin branch-name
gh pr create
```

## IDE (Zed)
```bash
# Launch Zed from nix develop (important for LSP)
zed .
```

## Slint UI
- UI files are in `src/ui/*.slint`
- Changes require rebuild (`cargo build`)
- Use `slint-viewer` for previewing UI files
