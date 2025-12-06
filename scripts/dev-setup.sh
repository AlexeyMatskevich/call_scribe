#!/usr/bin/env bash
# Development environment setup script
# Called automatically by nix develop shellHook

# Add cargo bin to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Install slint-lsp if not present
if ! command -v slint-lsp &> /dev/null; then
  echo "Installing slint-lsp..."
  cargo install slint-lsp
fi

# Calculate hash of current LSP paths and versions to detect changes
ra_info="$(which rust-analyzer):$(rust-analyzer --version 2>/dev/null || echo 'unknown')"
slint_info="$(which slint-lsp):$(slint-lsp --version 2>/dev/null || echo 'unknown')"
nixd_info="$(which nixd):$(nixd --version 2>/dev/null || echo 'unknown')"
current_hash=$(echo "$ra_info:$slint_info:$nixd_info" | sha256sum | cut -d' ' -f1)
stored_hash=""
if [ -f .zed/.lsp-hash ]; then
  stored_hash=$(cat .zed/.lsp-hash)
fi

# Regenerate .zed/settings.json if paths changed or file doesn't exist
if [ ! -f .zed/settings.json ] || [ "$current_hash" != "$stored_hash" ]; then
  echo "Generating .zed/settings.json..."
  mkdir -p .zed
  cat > .zed/settings.json << EOF
{
  "lsp": {
    "rust-analyzer": {
      "binary": {
        "path": "$(which rust-analyzer)"
      }
    },
    "slint": {
      "binary": {
        "path": "$(which slint-lsp)"
      }
    },
    "nixd": {
      "binary": {
        "path": "$(which nixd)"
      }
    },
    "nil": {
      "binary": {
        "path": "$(which nixd)"
      }
    }
  },
  "languages": {
    "TOML": {
      "language_servers": ["taplo", "!package-version-server"]
    }
  }
}
EOF
  # Save hash for future comparison
  echo "$current_hash" > .zed/.lsp-hash
fi
