#!/usr/bin/env bash
# Build the HVH cheat with Rojo and merge it into the user's place.
#   ./build.sh <input_place.rbxlx> [output_place.rbxlx]
set -euo pipefail
cd "$(dirname "$0")"

PLACE_IN="${1:-place/Place122222.rbxlx}"
PLACE_OUT="${2:-build/Place122222_HVH.rbxlx}"

mkdir -p build

echo "==> rojo build cheat model"
rojo build cheat.project.json --output build/HvhCheat.rbxmx

echo "==> merging cheat into place"
python3 merge.py "$PLACE_IN" build/HvhCheat.rbxmx "$PLACE_OUT"

echo "==> done: $PLACE_OUT"
