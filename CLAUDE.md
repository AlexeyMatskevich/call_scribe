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

## Architecture

```
src/
├── main.rs          # Entry point, creates and runs HelloWorld window
└── ui/
    └── hello.slint  # Slint UI definition (compiled at build time)

build.rs             # Compiles .slint files via slint-build
scripts/
├── dev-setup.sh     # Auto-config generation (called by nix develop)
├── serena-mcp       # Generated wrapper for Serena MCP
├── context7-mcp     # Wrapper fetching API key from rbw
└── rustup           # Shim for NixOS compatibility
```

### Slint UI Build Process

1. `build.rs` calls `slint_build::compile("src/ui/hello.slint")`
2. This generates Rust code at compile time
3. `slint::include_modules!()` in `main.rs` includes the generated code
4. Components like `HelloWorld` become available as Rust structs

## Key Dependencies

- **slint** with `backend-winit` and `renderer-skia-opengl` features
- Skia renderer requires `clang`, `python3`, `fontconfig`, `freetype` (provided by flake.nix)
