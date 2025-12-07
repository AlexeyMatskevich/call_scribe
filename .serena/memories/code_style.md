# Code Style and Conventions

## Rust Code Style
- Follow standard Rust conventions (rustfmt)
- Use `cargo fmt` before committing
- Run `cargo clippy` to catch common issues

## Naming Conventions
- **Functions/Methods**: snake_case (`process_audio`, `get_transcript`)
- **Types/Structs**: PascalCase (`CallRecorder`, `TranscriptEntry`)
- **Constants**: SCREAMING_SNAKE_CASE (`MAX_BUFFER_SIZE`)
- **Modules**: snake_case (`audio_capture`, `ui_components`)

## Slint UI Conventions
- Component names: PascalCase (`HelloWorld`, `MainWindow`)
- Properties: kebab-case (`preferred-width`, `font-size`)
- Colors: hex format (`#2e7d32`, `#f0f0f0`)
- Use explicit sizing with `px` units

## File Organization
- Entry point: `src/main.rs`
- UI definitions: `src/ui/*.slint`
- Build scripts: `build.rs` (for slint-build)

## Error Handling
- Use `Result` for fallible operations
- Use `.unwrap()` only in main/tests or when failure is impossible
- Prefer `?` operator for error propagation
