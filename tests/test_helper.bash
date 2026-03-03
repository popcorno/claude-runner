#!/usr/bin/env bash
# test_helper.bash — shared setup/teardown for claude-runner bats tests

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PROJECT_ROOT/bin/claude-runner.sh"

# Source the script (source guard prevents main from running)
load_script() {
  # Reset all globals to defaults before sourcing
  TASKS_DIR="./tasks/open"
  DONE_DIR="./tasks/done"
  FAILED_DIR="./tasks/failed"
  DONE_STRATEGY="move"
  DEFAULT_MODEL="opus"
  TEST_COMMAND="npm test"
  AUTO_COMMIT=true
  COMMIT_PREFIX="feat"
  MAX_RETRIES=2
  SYSTEM_PROMPT=""
  STOP_ON_ERROR=true
  DANGEROUS_MODE=true

  CLI_TASKS_DIR=""
  SINGLE_TASK=""
  DRY_RUN=false
  FROM_TASK=""
  VERBOSE=false
  LIST_ONLY=false

  REPORT_NAMES=()
  REPORT_MODELS=()
  REPORT_STATUSES=()
  REPORT_TIMES=()
  REPORT_NOTES=()
  TASKS_DONE=0
  TASKS_TOTAL=0
  HAD_ERRORS=false

  # Disable color for predictable test output
  RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" DIM="" RESET=""

  source "$SCRIPT"
}

# Create a temporary working directory and cd into it
setup_tmpdir() {
  TEST_TMPDIR="$(mktemp -d)"
  ORIG_DIR="$(pwd)"
  cd "$TEST_TMPDIR"
}

# Clean up the temporary directory
teardown_tmpdir() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_TMPDIR"
}

# Create a markdown task file with optional frontmatter
# Usage: create_task <path> [frontmatter] [body]
create_task() {
  local path="$1"
  local frontmatter="${2:-}"
  local body="${3:-# Task\n\nDo something.}"

  mkdir -p "$(dirname "$path")"
  if [[ -n "$frontmatter" ]]; then
    printf -- '---\n%b\n---\n%b\n' "$frontmatter" "$body" > "$path"
  else
    printf '%b\n' "$body" > "$path"
  fi
}

# Create a mock executable in the given directory
# Usage: create_mock <dir> <name> [script_body]
create_mock() {
  local dir="$1"
  local name="$2"
  local body="${3:-exit 0}"

  mkdir -p "$dir"
  cat > "$dir/$name" <<MOCK
#!/usr/bin/env bash
$body
MOCK
  chmod +x "$dir/$name"
}

# Prepend a mock bin directory to PATH
# Usage: inject_mock_path <dir>
inject_mock_path() {
  export PATH="$1:$PATH"
}
