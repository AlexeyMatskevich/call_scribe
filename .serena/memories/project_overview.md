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
│   ├── main.rs              # Entry point, runs MainWindow
│   └── ui/
│       ├── app.slint        # UI entry point (exports MainWindow)
│       ├── app/             # Application shell
│       │   ├── main_window.slint   # Responsive layout
│       │   └── main_content.slint  # Header + page routing
│       ├── pages/           # Sessions, Settings, etc.
│       ├── shared/          # Reusable components
│       │   ├── tokens.slint       # Theme, Spacing, Typography
│       │   ├── types.slint        # Data structures (NavItemData)
│       │   └── components/        # Buttons, overlays, etc.
│       ├── widgets/         # Feature-specific widgets
│       │   ├── app_header/        # Header components
│       │   └── navigation/        # Sidebar, drawer
│       └── assets/icons/    # SVG icons
├── build.rs              # Slint compilation (compiles app.slint)
├── Cargo.toml            # Rust dependencies
├── flake.nix             # Nix development environment
├── CLAUDE.md             # Instructions for Claude Code agent
├── scripts/
│   ├── dev-setup.sh      # Auto-generates configs on nix develop
│   ├── serena-mcp        # Generated wrapper for Serena MCP
│   ├── context7-mcp      # Wrapper for Context7 MCP
│   ├── github-mcp        # Wrapper for GitHub MCP
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

## Related Memories
- **slint-ui-patterns-pitfalls** - Read when working with Slint UI (alignment issues, binding loops, SVG icons, responsive patterns)
