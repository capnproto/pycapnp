#!/usr/bin/env bash
# Download GitHub Actions build artifacts for a tagged commit (or specific run
# ID) and upload the wheels + sdist to PyPI via twine.
#
# Usage:
#   scripts/release-pypi.sh <tag-or-run-id> [output-dir] [--force]
#
# Examples:
#   scripts/release-pypi.sh v2.2.1
#   scripts/release-pypi.sh 2.2.1 dist_221
#   scripts/release-pypi.sh 1234567890 dist_run_1234567890
#
# Requirements:
#   - gh CLI (authenticated; `gh auth status` must succeed)
#   - python3
#   - Twine credentials configured in the environment or ~/.pypirc
#     (TWINE_USERNAME / TWINE_PASSWORD, or an API token).

set -euo pipefail

WORKFLOW_FILE="wheels.yml"
ARTIFACT_PATTERN="cibw-*"
VENV_DIR=".venv-release"

usage() {
    cat >&2 <<EOF
Usage: $0 <tag-or-run-id> [output-dir] [--force]

  <tag-or-run-id>  Git tag (e.g. v2.2.1 or 2.2.1) or a GitHub Actions run ID.
  [output-dir]     Directory to place wheels/sdist into. Defaults to
                   dist_<digits> for a tag, or dist_run_<id> for a run ID.
  --force          Allow reusing a non-empty output directory.
EOF
    exit 2
}

die() {
    echo "error: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found in PATH"
}

FORCE=0
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h|--help) usage ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done

[[ ${#POSITIONAL[@]} -ge 1 && ${#POSITIONAL[@]} -le 2 ]] || usage

INPUT="${POSITIONAL[0]}"
OUTPUT_DIR="${POSITIONAL[1]:-}"

require_cmd gh
require_cmd python3

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo ">> verifying gh authentication"
gh auth status >/dev/null || die "gh is not authenticated; run 'gh auth login'"

# Resolve run ID. A bare integer is treated as a run ID; otherwise we look up
# the latest successful run on the branch/tag matching the build workflow.
if [[ "$INPUT" =~ ^[0-9]+$ ]]; then
    RUN_ID="$INPUT"
    DEFAULT_OUT="dist_run_${RUN_ID}"
    echo ">> using GitHub Actions run id: $RUN_ID"
elif [[ "$INPUT" =~ ^v?[0-9].* ]]; then
    TAG="$INPUT"
    TAG_NO_V="${TAG#v}"
    DEFAULT_OUT="dist_${TAG_NO_V//./}"
    echo ">> resolving latest successful '$WORKFLOW_FILE' run for tag '$TAG'"
    RUN_ID="$(gh run list \
        --workflow="$WORKFLOW_FILE" \
        --branch "$TAG" \
        --status success \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId')"
    if [[ -z "${RUN_ID:-}" || "$RUN_ID" == "null" ]]; then
        die "no successful '$WORKFLOW_FILE' run found for tag '$TAG'"
    fi
    echo ">> resolved run id: $RUN_ID"
else
    die "first arg must be a git tag (vX.Y.Z) or a numeric run ID"
fi

OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUT}"

if [[ -e "$OUTPUT_DIR" ]]; then
    if [[ -d "$OUTPUT_DIR" ]]; then
        if [[ -n "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" && "$FORCE" -ne 1 ]]; then
            die "'$OUTPUT_DIR' is not empty; pass --force to reuse it"
        fi
    else
        die "'$OUTPUT_DIR' exists and is not a directory"
    fi
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

TMP_DIR="$(mktemp -d -t pycapnp-release-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo ">> downloading artifacts (pattern '$ARTIFACT_PATTERN') into $TMP_DIR"
gh run download "$RUN_ID" --dir "$TMP_DIR" --pattern "$ARTIFACT_PATTERN"

echo ">> flattening wheels and sdists into $OUTPUT_DIR_ABS"
shopt -s nullglob globstar
moved=0
for f in "$TMP_DIR"/**/*.whl "$TMP_DIR"/**/*.tar.gz; do
    [[ -f "$f" ]] || continue
    mv -n "$f" "$OUTPUT_DIR_ABS/"
    moved=$((moved + 1))
done
shopt -u globstar
[[ "$moved" -gt 0 ]] || die "no .whl or .tar.gz files found in downloaded artifacts"
echo ">> collected $moved files"

echo ">> setting up release virtualenv at $VENV_DIR"
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    python3 -m venv "$VENV_DIR"
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install --quiet --upgrade pip
python -m pip install --quiet --upgrade twine

echo ">> running 'twine check'"
python -m twine check "$OUTPUT_DIR_ABS"/*

echo
echo "Files to upload from $OUTPUT_DIR_ABS:"
ls -1 "$OUTPUT_DIR_ABS"
echo
read -r -p "Upload these to PyPI? [y/N] " reply
case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "aborted; files remain in $OUTPUT_DIR_ABS"; exit 0 ;;
esac

echo ">> uploading to PyPI via twine"
python -m twine upload "$OUTPUT_DIR_ABS"/*

echo ">> done"
