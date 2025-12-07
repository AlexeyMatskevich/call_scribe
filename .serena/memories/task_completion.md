# What to Do When a Task is Completed

## Before Committing
1. **Format code**: `cargo fmt`
2. **Run linter**: `cargo clippy`
3. **Run tests**: `cargo test`
4. **Build check**: `cargo build`

## Commit Guidelines
- Use descriptive commit messages
- Format: `<type>: <description>`
- Types: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`
- Example: `feat: add audio capture module`

## For UI Changes
- Verify UI renders correctly: `cargo run`
- Check Slint syntax: build will fail if invalid

## Pull Request Checklist
- [ ] Code formatted (`cargo fmt`)
- [ ] No clippy warnings (`cargo clippy`)
- [ ] Tests pass (`cargo test`)
- [ ] Application runs (`cargo run`)
- [ ] Commit message is descriptive
