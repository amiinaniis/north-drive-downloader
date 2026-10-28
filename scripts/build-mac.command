#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
exec /bin/zsh "$(pwd)/scripts/build-dmg.command"
