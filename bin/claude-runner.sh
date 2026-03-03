#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════
#  claude-runner — automated sequential
#  task execution via Claude Code
# ═══════════════════════════════════════

VERSION="1.4.0"

# ── Color setup ──────────────────────────────────────────────
if [[ -t 1 ]] && command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  BOLD=$(tput bold)
  DIM=$(tput dim)
  RESET=$(tput sgr0)
else
  RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" DIM="" RESET=""
fi

# ── Defaults ─────────────────────────────────────────────────
TASKS_DIR="./tasks/open"
DONE_DIR="./tasks/done"
FAILED_DIR="./tasks/failed"
BACKLOG_DIR="./tasks/backlog"
DONE_STRATEGY="move"
DEFAULT_MODEL="opus"
TEST_COMMAND="npm test"
AUTO_COMMIT=true
COMMIT_PREFIX="feat"
MAX_RETRIES=2
SYSTEM_PROMPT=""
STOP_ON_ERROR=true
DANGEROUS_MODE=true

# ── CLI state ────────────────────────────────────────────────
CLI_TASKS_DIR=""
SINGLE_TASK=""
DRY_RUN=false
FROM_TASK=""
VERBOSE=false
LIST_ONLY=false
LIST_BACKLOG=false

# ── Report data ──────────────────────────────────────────────
declare -a REPORT_NAMES=()
declare -a REPORT_MODELS=()
declare -a REPORT_STATUSES=()
declare -a REPORT_TIMES=()
declare -a REPORT_NOTES=()
declare -a REPORT_COSTS=()
TASKS_DONE=0
TASKS_TOTAL=0
HAD_ERRORS=false

# ── Parsed Claude output globals ─────────────────────────────
PARSED_RESULT=""
PARSED_COST_USD=""

# ── Logging ──────────────────────────────────────────────────
log_info()    { echo "${BLUE}${BOLD}ℹ${RESET} $*"; }
log_success() { echo "${GREEN}${BOLD}✅${RESET} $*"; }
log_warn()    { echo "${YELLOW}${BOLD}⚠${RESET} $*"; }
log_error()   { echo "${RED}${BOLD}❌${RESET} $*"; }
log_verbose() { [[ "$VERBOSE" == true ]] && echo "${DIM}  $*${RESET}" || true; }
log_step()    { echo "${CYAN}${BOLD}▶${RESET} $*"; }

# ── Parse Claude CLI JSON output ─────────────────────────────
# Sets PARSED_RESULT (text to display) and PARSED_COST_USD globals.
# Falls back to raw output if JSON parsing fails.
parse_claude_output() {
  local json="$1"
  PARSED_RESULT=""
  PARSED_COST_USD=""

  if echo "$json" | jq -e 'type == "object"' >/dev/null 2>&1; then
    PARSED_RESULT=$(echo "$json" | jq -r '.result // ""')
    PARSED_COST_USD=$(echo "$json" | jq -r '.total_cost_usd | values' 2>/dev/null || echo "")
  else
    PARSED_RESULT="$json"
  fi
}

# ── Usage ────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}claude-runner${RESET} v${VERSION} — automated sequential task execution via Claude Code

${BOLD}USAGE${RESET}
  claude-runner [tasks-dir] [options]

${BOLD}OPTIONS${RESET}
  ${BOLD}--task <file>${RESET}       Run a single task file
  ${BOLD}--dry-run${RESET}           Show execution plan without running
  ${BOLD}--from <prefix>${RESET}     Start from task matching prefix (skip earlier ones)
  ${BOLD}--verbose${RESET}           Verbose output
  ${BOLD}--list${RESET}              List open tasks and exit
  ${BOLD}--list-backlog${RESET}      List backlog tasks and exit
  ${BOLD}--version${RESET}           Show version
  ${BOLD}--help${RESET}              Show this help

${BOLD}EXAMPLES${RESET}
  claude-runner                        # Run tasks from ./tasks/open/
  claude-runner ./sprint-3             # Run tasks from ./sprint-3/
  claude-runner --task ./tasks/open/003.md  # Run a single task
  claude-runner --dry-run              # Preview execution plan
  claude-runner --from 003             # Start from task 003
  claude-runner --list                 # Show open tasks

${BOLD}CONFIGURATION${RESET}
  Place ${CYAN}claude-runner.config.json${RESET} or ${CYAN}.claude-runner.json${RESET} in your project root.
  See README for all configuration options.
EOF
}

# ── Frontmatter parsing ─────────────────────────────────────
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

get_task_body() {
  local file="$1"
  # If file has frontmatter (starts with ---), return everything after second ---
  # If no frontmatter, return the entire file
  if head -1 "$file" | grep -q '^---$'; then
    awk '/^---$/ { fm++; next } fm >= 2 { print }' "$file"
  else
    cat "$file"
  fi
}

get_task_title() {
  local file="$1"
  get_task_body "$file" | awk '/^# / { sub(/^# */, ""); print; exit }'
}

# ── Validate frontmatter field values ───────────────────────
# Returns validated value or default. Warns on invalid values.
# Usage: validated=$(validate_frontmatter "priority" "$raw_value" "medium")
validate_frontmatter() {
  local field="$1"
  local value="$2"
  local default="$3"

  [[ -z "$value" ]] && { echo "$default"; return 0; }

  case "$field" in
    priority)
      case "$value" in
        high|medium|low) echo "$value" ;;
        *) log_warn "Invalid priority '$value', using default '$default'" >&2
           echo "$default" ;;
      esac
      ;;
    skip-tests)
      case "$value" in
        true|false) echo "$value" ;;
        *) log_warn "Invalid skip-tests '$value', using default '$default'" >&2
           echo "$default" ;;
      esac
      ;;
    model)
      case "$value" in
        opus|sonnet|haiku|opusplan) echo "$value" ;;
        claude-*|anthropic.*) echo "$value" ;;
        *) log_warn "Invalid model '$value', using default '$default'" >&2
           echo "$default" ;;
      esac
      ;;
    *)
      echo "$value"
      ;;
  esac
}

# ── Config loading ───────────────────────────────────────────
load_config() {
  local config_file=""

  if [[ -f "claude-runner.config.json" ]]; then
    config_file="claude-runner.config.json"
  elif [[ -f ".claude-runner.json" ]]; then
    config_file=".claude-runner.json"
  fi

  if [[ -z "$config_file" ]]; then
    log_verbose "No config file found, using defaults"
    return
  fi

  log_verbose "Loading config from $config_file"

  local val

  val=$(jq -r '.tasksDir | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && TASKS_DIR="$val"
  val=$(jq -r '.doneDir | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && DONE_DIR="$val"
  val=$(jq -r '.failedDir | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && FAILED_DIR="$val"
  val=$(jq -r '.backlogDir | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && BACKLOG_DIR="$val"
  val=$(jq -r '.doneStrategy | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && DONE_STRATEGY="$val"
  val=$(jq -r '.defaultModel | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && DEFAULT_MODEL="$val"
  val=$(jq -r '.testCommand | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && TEST_COMMAND="$val"
  val=$(jq -r '.autoCommit | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && AUTO_COMMIT="$val"
  val=$(jq -r '.commitPrefix | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && COMMIT_PREFIX="$val"
  val=$(jq -r '.maxRetries | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && MAX_RETRIES="$val"
  val=$(jq -r '.systemPrompt | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && SYSTEM_PROMPT="$val"
  val=$(jq -r '.stopOnError | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && STOP_ON_ERROR="$val"
  val=$(jq -r '.allowDangerousMode | values' "$config_file" 2>/dev/null) && [[ -n "$val" ]] && DANGEROUS_MODE="$val"

  return 0
}

# ── CLI argument parsing ─────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task)
        [[ $# -lt 2 ]] && { log_error "--task requires a file path"; exit 1; }
        SINGLE_TASK="$2"; shift 2 ;;
      --dry-run)
        DRY_RUN=true; shift ;;
      --from)
        [[ $# -lt 2 ]] && { log_error "--from requires a prefix"; exit 1; }
        FROM_TASK="$2"; shift 2 ;;
      --verbose)
        VERBOSE=true; shift ;;
      --list)
        LIST_ONLY=true; shift ;;
      --list-backlog)
        LIST_BACKLOG=true; shift ;;
      --version)
        echo "claude-runner v${VERSION}"; exit 0 ;;
      --help|-h)
        usage; exit 0 ;;
      -*)
        log_error "Unknown option: $1"; usage; exit 1 ;;
      *)
        CLI_TASKS_DIR="$1"; shift ;;
    esac
  done

  # CLI tasks dir overrides config
  if [[ -n "$CLI_TASKS_DIR" ]]; then
    TASKS_DIR="$CLI_TASKS_DIR"
  fi
}

# ── Prerequisite checks ─────────────────────────────────────
check_prerequisites() {
  if ! command -v claude &>/dev/null; then
    log_error "claude CLI not found in PATH"
    echo "  Install it from: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    log_error "jq not found in PATH"
    echo "  Install: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
  fi

  if ! command -v git &>/dev/null; then
    log_error "git not found in PATH"
    exit 1
  fi

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_error "Not inside a git repository"
    echo "  Run 'git init' first or cd into a git project"
    exit 1
  fi
}

# ── Collect and sort tasks ───────────────────────────────────
collect_tasks() {
  local tasks_dir="$1"
  local -a high=() medium=() low=()

  if [[ ! -d "$tasks_dir" ]]; then
    log_error "Tasks directory not found: $tasks_dir"
    exit 1
  fi

  local found_md=false
  for file in "$tasks_dir"/*.md; do
    [[ -f "$file" ]] || continue
    found_md=true

    # In "move" strategy, all files in tasksDir are considered open.
    # In "status" strategy, filter by frontmatter status field.
    if [[ "$DONE_STRATEGY" == "status" ]]; then
      local status
      status=$(get_frontmatter_value "$file" "status")
      [[ -z "$status" ]] && status="open"
      [[ "$status" != "open" ]] && continue
    fi

    local priority
    priority=$(get_frontmatter_value "$file" "priority")
    priority=$(validate_frontmatter "priority" "$priority" "medium")

    case "$priority" in
      high)   high+=("$file") ;;
      low)    low+=("$file") ;;
      *)      medium+=("$file") ;;
    esac
  done

  if [[ "$found_md" == false ]]; then
    log_error "No .md files found in $tasks_dir"
    exit 1
  fi

  # Sort within each priority group by filename
  IFS=$'\n'
  [[ ${#high[@]} -gt 0 ]]   && high=($(printf '%s\n' "${high[@]}" | sort))
  [[ ${#medium[@]} -gt 0 ]] && medium=($(printf '%s\n' "${medium[@]}" | sort))
  [[ ${#low[@]} -gt 0 ]]    && low=($(printf '%s\n' "${low[@]}" | sort))
  unset IFS

  SORTED_TASKS=("${high[@]+"${high[@]}"}" "${medium[@]+"${medium[@]}"}" "${low[@]+"${low[@]}"}")
}

# ── Format elapsed time ─────────────────────────────────────
format_time() {
  local seconds="$1"
  if (( seconds >= 60 )); then
    printf "%dm%ds" $((seconds / 60)) $((seconds % 60))
  else
    printf "%ds" "$seconds"
  fi
}

# ── Format cost for display ──────────────────────────────────
format_cost() {
  local cost="$1"
  if [[ -z "$cost" ]]; then
    echo "-"
  else
    printf "\$%.4f" "$cost"
  fi
}

# ── Move task file to target directory ───────────────────────
move_task() {
  local task_file="$1"
  local target_dir="$2"
  local filename
  filename=$(basename "$task_file")

  mkdir -p "$target_dir"

  if [[ -f "$task_file" ]]; then
    mv "$task_file" "${target_dir}/${filename}"
    log_verbose "Moved $filename → $target_dir/"
  elif [[ -f "${target_dir}/${filename}" ]]; then
    log_verbose "$filename already in $target_dir/ (moved by Claude?)"
  else
    log_warn "Task file not found: $task_file (may have been moved or deleted by Claude)"
  fi
}

# ── Set a field in frontmatter ────────────────────────────────
# Handles three cases:
#   1. File already has the field → replace it
#   2. File has frontmatter but not this field → insert after opening ---
#   3. File has no frontmatter → prepend frontmatter block with field
set_frontmatter_field() {
  local file="$1"
  local field="$2"
  local value="$3"

  [[ -f "$file" ]] || return 0

  local sed_i=(-i)
  [[ "$OSTYPE" == "darwin"* ]] && sed_i=(-i '')

  # Case 1: file already has this field in frontmatter
  if grep -q "^${field}:" "$file"; then
    sed "${sed_i[@]}" "s/^${field}:.*$/${field}: ${value}/" "$file"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  trap "rm -f '$tmp'" RETURN

  # Case 2: file has frontmatter (starts with ---) but no field
  if head -1 "$file" | grep -q '^---$'; then
    awk -v field="$field" -v value="$value" '
      /^---$/ && !done { print; print field ": " value; done=1; next }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    return 0
  fi

  # Case 3: no frontmatter at all — prepend it
  printf '%s\n' "---" "${field}: ${value}" "---" > "$tmp"
  cat "$file" >> "$tmp"
  mv "$tmp" "$file"
}

# ── Update frontmatter status field ──────────────────────────
set_frontmatter_status() {
  set_frontmatter_field "$1" "status" "$2"
}

# ── Mark task as done ────────────────────────────────────────
mark_task_done() {
  local task_file="$1"

  if [[ "$DONE_STRATEGY" == "move" ]]; then
    move_task "$task_file" "$DONE_DIR"
  else
    set_frontmatter_status "$task_file" "done"
  fi
}

# ── Mark task as failed ──────────────────────────────────────
mark_task_failed() {
  local task_file="$1"

  if [[ "$DONE_STRATEGY" == "move" ]]; then
    move_task "$task_file" "$FAILED_DIR"
  fi
  # In "status" strategy, failed tasks keep status: open (no change)
}

# ── Resolve permission flags ─────────────────────────────────
resolve_permission_flag() {
  if [[ "$DANGEROUS_MODE" == true ]]; then
    echo "--dangerously-skip-permissions"
  fi
}

# ── Resolve model flags ─────────────────────────────────────
resolve_model_flag() {
  local model="$1"
  case "$model" in
    opusplan)
      echo "--model opus"
      ;;
    opus|sonnet|haiku)
      echo "--model $model"
      ;;
    *)
      # Full model name
      echo "--model $model"
      ;;
  esac
}

# ── Run a single task ────────────────────────────────────────
run_task() {
  local task_file="$1"
  local task_name
  task_name=$(basename "$task_file" .md)

  local title
  title=$(get_task_title "$task_file")
  [[ -z "$title" ]] && title="$task_name"

  local model skip_tests commit_msg priority
  model=$(get_frontmatter_value "$task_file" "model")
  model=$(validate_frontmatter "model" "$model" "$DEFAULT_MODEL")
  skip_tests=$(get_frontmatter_value "$task_file" "skip-tests")
  skip_tests=$(validate_frontmatter "skip-tests" "$skip_tests" "false")
  commit_msg=$(get_frontmatter_value "$task_file" "commit-message")
  priority=$(get_frontmatter_value "$task_file" "priority")
  priority=$(validate_frontmatter "priority" "$priority" "medium")

  echo ""
  echo "${BOLD}═══════════════════════════════════════${RESET}"
  echo "  ${CYAN}${BOLD}Task:${RESET} ${BOLD}$title${RESET}"
  echo "  ${DIM}File: $task_file${RESET}"
  echo "  ${DIM}Model: $model | Priority: $priority${RESET}"
  echo "${BOLD}═══════════════════════════════════════${RESET}"

  local start_time
  start_time=$(date +%s)

  # Build prompt
  local body
  body=$(get_task_body "$task_file")

  # Skip empty tasks
  local body_trimmed="${body//[$'\t\n\r ']}"
  if [[ -z "$body_trimmed" ]]; then
    log_warn "Empty task body: $task_file — skipping"
    local elapsed=$(( $(date +%s) - start_time ))
    mark_task_done "$task_file"
    record_result "$task_name" "$model" "skipped" "$(format_time $elapsed)" "empty task"
    return 0
  fi

  local prompt=""
  if [[ -n "$SYSTEM_PROMPT" ]]; then
    prompt="${SYSTEM_PROMPT}

"
  fi
  prompt+="$body

IMPORTANT: Do not modify, move, or delete task files in the tasks/ directory. Task lifecycle is managed by claude-runner automatically."

  # Resolve flags
  local model_flag perm_flag
  model_flag=$(resolve_model_flag "$model")
  perm_flag=$(resolve_permission_flag)

  # Run Claude
  log_step "Running Claude ($model)..."
  log_verbose "Prompt length: ${#prompt} chars"

  local total_cost=""
  local claude_exit=0
  local raw_output
  raw_output=$(echo "$prompt" | claude -p - $model_flag $perm_flag --output-format json 2>&1) || claude_exit=$?

  parse_claude_output "$raw_output"
  [[ -n "$PARSED_COST_USD" ]] && total_cost="$PARSED_COST_USD"

  if [[ "$VERBOSE" == true ]]; then
    echo "$PARSED_RESULT"
  else
    echo "$PARSED_RESULT" | tail -20
  fi

  if [[ $claude_exit -ne 0 ]]; then
    local elapsed=$(( $(date +%s) - start_time ))
    log_error "Claude exited with code $claude_exit"
    [[ -n "$total_cost" ]] && set_frontmatter_field "$task_file" "cost" "$total_cost"
    mark_task_failed "$task_file"
    record_result "$task_name" "$model" "error" "$(format_time $elapsed)" "claude exit $claude_exit" "$total_cost"
    return 1
  fi

  # Run tests
  local retries=0
  if [[ "$skip_tests" != "true" ]]; then
    while true; do
      log_step "Running tests: $TEST_COMMAND"
      local test_output test_exit=0
      test_output=$(eval "$TEST_COMMAND" 2>&1) || test_exit=$?

      if [[ $test_exit -eq 0 ]]; then
        log_success "Tests passed"
        break
      fi

      retries=$((retries + 1))
      if (( retries > MAX_RETRIES )); then
        local elapsed=$(( $(date +%s) - start_time ))
        log_error "Tests failed after $MAX_RETRIES retries, rolling back"

        # Rollback code changes
        git checkout . 2>/dev/null || true
        git clean -fd 2>/dev/null || true

        # Move task to failed
        [[ -n "$total_cost" ]] && set_frontmatter_field "$task_file" "cost" "$total_cost"
        mark_task_failed "$task_file"

        record_result "$task_name" "$model" "rollback" "$(format_time $elapsed)" "" "$total_cost"
        return 1
      fi

      log_warn "Tests failed (attempt $retries/$MAX_RETRIES), asking Claude to fix..."
      log_verbose "$test_output"

      local fix_prompt="REMINDER: You are working on the following task. You MUST follow ALL constraints from the original task:

$body

---

The tests failed with the following output. Please fix the code to make the tests pass.

Test command: $TEST_COMMAND

Test output:
\`\`\`
$test_output
\`\`\`

IMPORTANT: Do not modify, move, or delete task files in the tasks/ directory. Task lifecycle is managed by claude-runner automatically."

      local fix_output
      fix_output=$(echo "$fix_prompt" | claude -p - $model_flag $perm_flag --output-format json 2>&1) || true

      parse_claude_output "$fix_output"
      if [[ -n "$PARSED_COST_USD" ]]; then
        if [[ -z "$total_cost" ]]; then
          total_cost="$PARSED_COST_USD"
        else
          total_cost=$(jq -n "$total_cost + $PARSED_COST_USD" 2>/dev/null || echo "$total_cost")
        fi
      fi

      if [[ "$VERBOSE" == true ]]; then
        echo "$PARSED_RESULT"
      else
        echo "$PARSED_RESULT" | tail -20
      fi
    done
  else
    log_verbose "Skipping tests (skip-tests: true)"
  fi

  local elapsed=$(( $(date +%s) - start_time ))
  local note=""
  (( retries > 0 )) && note="$retries retry"

  # Commit
  if [[ "$AUTO_COMMIT" == true ]]; then
    # Mark task as done (move or update status)
    [[ -n "$total_cost" ]] && set_frontmatter_field "$task_file" "cost" "$total_cost"
    mark_task_done "$task_file"

    # Build commit message
    if [[ -z "$commit_msg" ]]; then
      commit_msg="${COMMIT_PREFIX}: ${title}"
    fi

    git add -A
    git commit -m "$commit_msg" 2>/dev/null || {
      log_warn "Nothing to commit (no changes made)"
    }
    log_success "Committed: $commit_msg"
  else
    [[ -n "$total_cost" ]] && set_frontmatter_field "$task_file" "cost" "$total_cost"
    mark_task_done "$task_file"
    log_success "Done (auto-commit disabled)"
  fi

  record_result "$task_name" "$model" "done" "$(format_time $elapsed)" "$note" "$total_cost"
  return 0
}

# ── Record result for report ────────────────────────────────
record_result() {
  REPORT_NAMES+=("$1")
  REPORT_MODELS+=("$2")
  REPORT_STATUSES+=("$3")
  REPORT_TIMES+=("$4")
  REPORT_NOTES+=("$5")
  REPORT_COSTS+=("${6:-}")
}

# ── Print final report ──────────────────────────────────────
print_report() {
  echo ""
  echo "${BOLD}═══════════════════════════════════════${RESET}"
  echo "  ${BOLD}claude-runner — Report${RESET}"
  echo "${BOLD}═══════════════════════════════════════${RESET}"

  local i
  local total_cost=""
  for (( i = 0; i < ${#REPORT_NAMES[@]}; i++ )); do
    local icon name model status time_str note cost cost_str
    name="${REPORT_NAMES[$i]}"
    model="${REPORT_MODELS[$i]}"
    status="${REPORT_STATUSES[$i]}"
    time_str="${REPORT_TIMES[$i]}"
    note="${REPORT_NOTES[$i]}"
    cost="${REPORT_COSTS[$i]:-}"
    cost_str=$(format_cost "$cost")

    case "$status" in
      done)     icon="${GREEN}✅${RESET}" ;;
      rollback) icon="${RED}❌${RESET}"; time_str="rollback" ;;
      error)    icon="${RED}❌${RESET}" ;;
      skipped)  icon="${YELLOW}⏭️${RESET}"; time_str="skipped" ;;
    esac

    local extra=""
    [[ -n "$note" ]] && extra="  (${note})"

    printf "  %s %-25s %-10s %-10s %s%s\n" "$icon" "$name" "$model" "$time_str" "$cost_str" "$extra"

    if [[ -n "$cost" ]]; then
      if [[ -z "$total_cost" ]]; then
        total_cost="$cost"
      else
        total_cost=$(jq -n "$total_cost + $cost" 2>/dev/null || echo "$total_cost")
      fi
    fi
  done

  local total_cost_str
  total_cost_str=$(format_cost "$total_cost")

  echo "${BOLD}═══════════════════════════════════════${RESET}"
  echo "  ${BOLD}Total: ${TASKS_DONE}/${TASKS_TOTAL} completed | Cost: ${total_cost_str}${RESET}"
  echo "${BOLD}═══════════════════════════════════════${RESET}"
  echo ""
}

# ── List tasks ───────────────────────────────────────────────
list_tasks() {
  local tasks_dir="$1"
  collect_tasks "$tasks_dir"

  if [[ ${#SORTED_TASKS[@]} -eq 0 ]]; then
    log_info "No open tasks found"
    return
  fi

  echo ""
  echo "${BOLD}Open tasks in ${tasks_dir}:${RESET}"
  echo ""

  local i
  for (( i = 0; i < ${#SORTED_TASKS[@]}; i++ )); do
    local file="${SORTED_TASKS[$i]}"
    local name priority model title
    name=$(basename "$file" .md)
    priority=$(get_frontmatter_value "$file" "priority")
    [[ -z "$priority" ]] && priority="medium"
    model=$(get_frontmatter_value "$file" "model")
    [[ -z "$model" ]] && model="$DEFAULT_MODEL"
    title=$(get_task_title "$file")
    [[ -z "$title" ]] && title="$name"

    local pcolor
    case "$priority" in
      high) pcolor="$RED" ;;
      low)  pcolor="$DIM" ;;
      *)    pcolor="$YELLOW" ;;
    esac

    printf "  ${BOLD}%s${RESET}  ${pcolor}%-6s${RESET}  %-8s  %s\n" "$name" "$priority" "$model" "$title"
  done
  echo ""
  echo "  ${DIM}Total: ${#SORTED_TASKS[@]} open tasks${RESET}"
  echo ""
}

# ── Dry run ──────────────────────────────────────────────────
dry_run() {
  local tasks_dir="$1"
  collect_tasks "$tasks_dir"

  if [[ ${#SORTED_TASKS[@]} -eq 0 ]]; then
    log_info "No open tasks to execute"
    return
  fi

  echo ""
  echo "${BOLD}${CYAN}Execution plan (dry run):${RESET}"
  echo ""

  local i order=1
  local skip=true
  for (( i = 0; i < ${#SORTED_TASKS[@]}; i++ )); do
    local file="${SORTED_TASKS[$i]}"
    local name priority model title skip_tests
    name=$(basename "$file" .md)

    # Handle --from
    if [[ -n "$FROM_TASK" ]]; then
      if [[ "$name" == *"$FROM_TASK"* ]]; then
        skip=false
      fi
      if [[ "$skip" == true ]]; then
        continue
      fi
    fi

    priority=$(get_frontmatter_value "$file" "priority")
    [[ -z "$priority" ]] && priority="medium"
    model=$(get_frontmatter_value "$file" "model")
    [[ -z "$model" ]] && model="$DEFAULT_MODEL"
    title=$(get_task_title "$file")
    [[ -z "$title" ]] && title="$name"
    skip_tests=$(get_frontmatter_value "$file" "skip-tests")

    local pcolor
    case "$priority" in
      high) pcolor="$RED" ;;
      low)  pcolor="$DIM" ;;
      *)    pcolor="$YELLOW" ;;
    esac

    local test_info="${GREEN}tests${RESET}"
    [[ "$skip_tests" == "true" ]] && test_info="${DIM}no tests${RESET}"

    printf "  ${BOLD}%d.${RESET} %-22s ${pcolor}%-6s${RESET} %-8s %s  [%s]\n" \
      "$order" "$name" "$priority" "$model" "$title" "$test_info"
    order=$((order + 1))
  done

  echo ""
  echo "  ${DIM}Strategy: $DONE_STRATEGY | Model: $DEFAULT_MODEL | Tests: $TEST_COMMAND | Retries: $MAX_RETRIES${RESET}"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────
main() {
  parse_args "$@"
  check_prerequisites
  load_config

  # Re-apply CLI overrides after config load
  if [[ -n "$CLI_TASKS_DIR" ]]; then
    TASKS_DIR="$CLI_TASKS_DIR"
  fi

  # List mode
  if [[ "$LIST_ONLY" == true ]]; then
    list_tasks "$TASKS_DIR"
    exit 0
  fi

  # List backlog mode
  if [[ "$LIST_BACKLOG" == true ]]; then
    if [[ ! -d "$BACKLOG_DIR" ]]; then
      log_info "No backlog directory: $BACKLOG_DIR"
      exit 0
    fi
    list_tasks "$BACKLOG_DIR"
    exit 0
  fi

  # Single task mode
  if [[ -n "$SINGLE_TASK" ]]; then
    # Resolve short filename against tasks directory
    if [[ ! -f "$SINGLE_TASK" && -f "${TASKS_DIR}/${SINGLE_TASK}" ]]; then
      SINGLE_TASK="${TASKS_DIR}/${SINGLE_TASK}"
    fi

    if [[ ! -f "$SINGLE_TASK" ]]; then
      log_error "Task file not found: $SINGLE_TASK"
      exit 1
    fi

    echo "${BOLD}claude-runner${RESET} v${VERSION}"
    echo ""

    TASKS_TOTAL=1
    if run_task "$SINGLE_TASK"; then
      TASKS_DONE=1
    else
      HAD_ERRORS=true
    fi
    print_report
    [[ "$HAD_ERRORS" == true ]] && exit 1
    exit 0
  fi

  # Dry run mode (collect_tasks is called inside dry_run)
  if [[ "$DRY_RUN" == true ]]; then
    dry_run "$TASKS_DIR"
    exit 0
  fi

  # Collect tasks
  collect_tasks "$TASKS_DIR"

  if [[ ${#SORTED_TASKS[@]} -eq 0 ]]; then
    log_info "No open tasks found in $TASKS_DIR"
    exit 0
  fi

  # Check for clean working tree (uncommitted changes would be lost on rollback)
  if ! git diff --quiet HEAD 2>/dev/null || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    log_warn "Working tree has uncommitted changes"
    log_warn "Rollback on failure will discard ALL uncommitted changes (git checkout . && git clean -fd)"
    echo ""
    read -r -p "  Continue anyway? [y/N] " confirm
    [[ "$confirm" != [yY] ]] && { log_info "Aborted"; exit 0; }
    echo ""
  fi

  # Ensure done/failed dirs exist for move strategy
  if [[ "$DONE_STRATEGY" == "move" ]]; then
    mkdir -p "$DONE_DIR" "$FAILED_DIR"
  fi

  # Run all tasks
  echo "${BOLD}claude-runner${RESET} v${VERSION}"
  echo "${DIM}Tasks: $TASKS_DIR → done: $DONE_DIR | failed: $FAILED_DIR${RESET}"
  echo "${DIM}Model: $DEFAULT_MODEL | Retries: $MAX_RETRIES | Strategy: $DONE_STRATEGY${RESET}"

  local skip=true
  [[ -z "$FROM_TASK" ]] && skip=false

  for file in "${SORTED_TASKS[@]}"; do
    local name
    name=$(basename "$file" .md)

    # Handle --from
    if [[ "$skip" == true ]]; then
      if [[ "$name" == *"$FROM_TASK"* ]]; then
        skip=false
      else
        log_verbose "Skipping $name (--from $FROM_TASK)"
        continue
      fi
    fi

    TASKS_TOTAL=$((TASKS_TOTAL + 1))

    if run_task "$file"; then
      TASKS_DONE=$((TASKS_DONE + 1))
    else
      HAD_ERRORS=true
      if [[ "$STOP_ON_ERROR" == true ]]; then
        log_error "Stopping due to error (stopOnError: true)"

        # Mark remaining tasks as skipped in report
        local found=false
        for remaining in "${SORTED_TASKS[@]}"; do
          if [[ "$found" == true ]]; then
            local rname rmodel
            rname=$(basename "$remaining" .md)
            rmodel=$(get_frontmatter_value "$remaining" "model")
            [[ -z "$rmodel" ]] && rmodel="$DEFAULT_MODEL"

            # Check if task is still in open dir (wasn't already processed)
            if [[ -f "$remaining" ]]; then
              record_result "$rname" "$rmodel" "skipped" "" ""
              TASKS_TOTAL=$((TASKS_TOTAL + 1))
            fi
          fi
          [[ "$remaining" == "$file" ]] && found=true
        done

        break
      else
        log_warn "Skipping failed task, continuing (stopOnError: false)"
      fi
    fi
  done

  print_report
  [[ "$HAD_ERRORS" == true ]] && exit 1
  exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
