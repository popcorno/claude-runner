#!/usr/bin/env bash
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────
DONE_DIR="./tasks/done"
MODEL=""

# ── Argument parsing ─────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --done-dir)
      DONE_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODEL" ]]; then
  echo "Error: --model is required" >&2
  exit 1
fi

# ── Hardcoded defaults ───────────────────────────────────────
get_default_cost() {
  local model="$1"
  case "$model" in
    haiku)    echo "0.0500" ;;
    sonnet)   echo "0.5000" ;;
    opus)     echo "3.0000" ;;
    opusplan) echo "4.0000" ;;
    *)        echo "1.0000" ;;
  esac
}

# ── Frontmatter parsing ──────────────────────────────────────
get_frontmatter_value() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    /^---$/ { fm++; next }
    fm == 1 && $0 ~ "^" key ":" {
      gsub(/^[^:]+:[[:space:]]*/, "")
      gsub(/[[:space:]]*$/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
    fm >= 2 { exit }
  ' "$file"
}

# ── Scan done dir and compute average ───────────────────────
costs=()
if [[ -d "$DONE_DIR" ]]; then
  for file in "$DONE_DIR"/*.md; do
    [[ -f "$file" ]] || continue
    file_model=$(get_frontmatter_value "$file" "model")
    file_cost=$(get_frontmatter_value "$file" "cost")
    if [[ "$file_model" == "$MODEL" && -n "$file_cost" ]]; then
      costs+=("$file_cost")
    fi
  done
fi

if [[ ${#costs[@]} -gt 0 ]]; then
  printf '%s\n' "${costs[@]}" | awk '{ sum += $1; count++ } END { printf "%.4f\n", sum / count }'
else
  get_default_cost "$MODEL"
fi
