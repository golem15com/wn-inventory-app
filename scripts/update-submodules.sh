#!/bin/bash
set -e

echo "Updating all Golem15 plugin submodules..."
cd "$(dirname "$0")/.."

# Update all submodules to latest remote master
git submodule update --remote --merge

echo ""
echo "Current submodule status:"
git submodule status

echo ""
echo "To commit these updates, run:"
echo "  git add plugins/golem15/"
echo "  git commit -m 'Update Golem15 plugin submodules'"
