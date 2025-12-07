# Call Scribe Project Overview

## Purpose
Call Scribe is a Rust desktop application for call transcription/note-taking (in development).

## Tech Stack
- **Language**: Rust (Edition 2024, Beta toolchain)
- **UI Framework**: Slint 1.14.1 with Skia OpenGL renderer
- **Build System**: Cargo + Nix Flakes
- **Development Environment**: Nix devShell with integrated LSP support

## Project Structure
```
call_scribe/
├── src/
│   ├── main.rs           # Application entry point
│   └── ui/
│       └── hello.slint   # Slint UI definitions
├── build.rs              # Slint compilation build script
├── Cargo.toml            # Rust dependencies
├── flake.nix             # Nix development environment
├── CLAUDE.md             # Instructions for Claude Code agent
├── scripts/
│   ├── dev-setup.sh      # Auto-generates configs on nix develop
│   ├── serena-mcp        # Generated wrapper for Serena MCP
│   ├── context7-mcp      # Wrapper for Context7 MCP (fetches API key from rbw)
│   ├── github-mcp        # Wrapper for GitHub MCP (fetches token from rbw)
│   └── rustup            # Shim for NixOS compatibility
└── .mcp.json             # MCP servers configuration (generated)
```

## MCP Servers

| Server | Purpose | Secret Source |
|--------|---------|---------------|
| **Serena** | Semantic code analysis via rust-analyzer | - |
| **Context7** | Library documentation lookup | `rbw get context7` |
| **GitHub** | Repository operations (read-only) | `rbw get github_personal_access_token` |

## Key Dependencies
- `slint` - UI framework with backend-winit and renderer-skia-opengl features
- `slint-build` - Build-time compilation of .slint files
