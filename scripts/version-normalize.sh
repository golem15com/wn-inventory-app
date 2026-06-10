#!/bin/bash
# scripts/version-normalize.sh
# READ-ONLY version.yaml latest-version extractor + normalizer (D-05, Phase 16).
#
# Takes one argument — a submodule path (e.g. plugins/golem15/chat) — and prints
# the normalized LATEST version from that plugin's updates/version.yaml to stdout
# (and nothing else). Exits 1 if the version.yaml is missing or has no version key.
#
# version.yaml is a chronological YAML map of "<version>: <changelog>"; the LATEST
# version is the LAST top-level key. Top-level keys have NO leading indentation;
# changelog children are indented 2-4 spaces. This script tolerates every observed
# key form and normalizes to a bare version (no surrounding quotes, no leading `v`):
#   unquoted no prefix : 1.2.0:        -> 1.2.0
#   unquoted v-prefix  : v1.1.2:       -> 1.1.2
#   double-quoted      : "3.1.0":      -> 3.1.0
#   single-quoted      : '1.1.0':      -> 1.1.0
#   scalar same-line   : 1.0.0: First… -> 1.0.0
#   two-part           : 2.5:          -> 2.5   (do NOT assume strict X.Y.Z)
#
# This script MUTATES NOTHING. It executes no state-changing git verbs whatsoever
# (no checkout, no tag, no commit, no push, no reset, no merge) — it only reads a
# file. Pin/tag actions are performed by the operator downstream, never in here.
#
# Usage:  bash scripts/version-normalize.sh plugins/golem15/chat
set -e
cd "$(dirname "$0")/.."

path="$1"
if [ -z "$path" ]; then
    echo "ERROR: usage: version-normalize.sh <submodule-path>" >&2
    exit 1
fi

vfile="$path/updates/version.yaml"
[ -f "$vfile" ] || { echo "ERROR: no $vfile" >&2; exit 1; }

# Top-level version keys = non-indented lines starting with an optional quote, an
# optional `v`, then a digit, up to the first colon. Last such key wins (chronological).
latest_raw="$(grep -E '^["'\'']?v?[0-9][^:]*:' "$vfile" | tail -1)"
[ -n "$latest_raw" ] || { echo "ERROR: no version key in $vfile" >&2; exit 1; }

# Strip the trailing ": <changelog>", then surrounding quotes, then a leading `v`.
ver="$(echo "$latest_raw" | sed -E 's/:.*$//; s/^["'\'']//; s/["'\'']$//; s/^v//')"
[ -n "$ver" ] || { echo "ERROR: empty version after normalize in $vfile" >&2; exit 1; }

echo "$ver"
