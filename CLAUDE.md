# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## MCP Tools Usage

### Context7 — Library Documentation

Always use Context7 MCP when you need code generation, setup/configuration steps, or library/API documentation. Automatically use `mcp__context7__resolve-library-id` and `mcp__context7__get-library-docs` to fetch current, version-specific documentation instead of relying on training data.

### Serena — Semantic Code Analysis

Use Serena MCP tools for intelligent code exploration and editing:
- **Exploring code**: Use `mcp__serena__get_symbols_overview` and `mcp__serena__find_symbol` instead of reading entire files
- **Finding usages**: Use `mcp__serena__find_referencing_symbols` to find all references to a symbol
- **Editing code**: Prefer `mcp__serena__replace_symbol_body`, `mcp__serena__insert_after_symbol` for precise symbol-level edits
- **Searching**: Use `mcp__serena__search_for_pattern` for regex searches across the codebase

## Project Overview

Call Scribe is a Rust desktop application using [Slint UI](https://slint.dev/) with Skia renderer for high-quality font rendering.

## Development Environment

This project uses **Nix flakes** for reproducible development. All tooling (Rust, LSPs, dependencies) is managed through `flake.nix`.

### Getting Started

```bash
nix develop          # Enter dev shell (auto-runs scripts/dev-setup.sh)
cargo run            # Run the application
cargo build          # Build the application
```

### NixOS-Specific Configuration

The `scripts/dev-setup.sh` script automatically generates configuration files on `nix develop`:

| Generated File | Purpose |
|---------------|---------|
| `.zed/settings.json` | Zed editor LSP paths |
| `.mcp.json` | MCP server configuration |
| `scripts/serena-mcp` | Wrapper with embedded nix store paths |
| `.venv/` | Python venv with Serena |

These files are gitignored because nix store paths change on updates. Regeneration is triggered automatically when LSP paths change.

### MCP Servers

Two MCP servers are configured:
- **Serena** — Semantic code analysis via rust-analyzer
- **Context7** — Library documentation (API key via `rbw get context7`)

The `scripts/rustup` shim exists because Serena expects `rustup which rust-analyzer` — it redirects to the nix-provided rust-analyzer.

### Direnv (NixOS and macOS)

This repo includes `.envrc` with `use flake` so direnv can load the dev shell automatically (including from Zed when `load_direnv` is enabled).

NixOS:
```bash
nix profile install nixpkgs#direnv nixpkgs#nix-direnv
```

macOS:
```bash
brew install direnv
nix profile install nixpkgs#nix-direnv
```

Then run:
```bash
direnv allow
```

## Architecture

```
src/
├── main.rs              # Entry point, creates and runs MainWindow
└── ui/
    ├── app.slint        # UI entry point (exports MainWindow)
    ├── app/             # Application shell
    │   ├── main_window.slint   # Responsive layout (sidebar + content + drawer)
    │   └── main_content.slint  # Header + page routing
    ├── pages/           # Page components (sessions, settings, etc.)
    ├── shared/          # Reusable across app
    │   ├── tokens.slint       # Theme, Spacing, Typography
    │   ├── types.slint        # Data structures
    │   └── components/        # Buttons, overlays, etc.
    ├── widgets/         # Feature-specific widgets
    │   ├── app_header/        # Header components
    │   └── navigation/        # Sidebar, drawer, nav items
    └── assets/icons/    # SVG icons

build.rs             # Compiles .slint files via slint-build
scripts/
├── dev-setup.sh     # Auto-config generation (called by nix develop)
├── serena-mcp       # Generated wrapper for Serena MCP
├── context7-mcp     # Wrapper fetching API key from rbw
└── rustup           # Shim for NixOS compatibility
```

### Slint UI Build Process

1. `build.rs` calls `slint_build::compile("src/ui/app.slint")`
2. This generates Rust code at compile time
3. `slint::include_modules!()` in `main.rs` includes the generated code
4. `MainWindow` component becomes available as a Rust struct

## Key Dependencies

- **slint** with `backend-winit` and `renderer-skia-opengl` features
- Skia renderer requires `clang`, `python3`, `fontconfig`, `freetype` (provided by flake.nix)

## Serena Memories

When working with Slint UI, read the `slint-ui-patterns-pitfalls` memory using:
```
mcp__serena__read_memory("slint-ui-patterns-pitfalls")
```

This contains documented solutions for common Slint issues:
- Vertical alignment (text appearing higher than icons)
- Binding loop warnings in responsive layouts
- SVG icon compatibility issues
- Conditional rendering patterns
