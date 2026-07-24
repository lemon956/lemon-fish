#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FUNCTION_FILE="$ROOT_DIR/functions/zed.fish"
readonly ORIGINAL_PATH="$PATH"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_file_equals() {
    local expected=$1
    local actual=$2
    local label=$3

    if ! cmp -s "$expected" "$actual"; then
        diff -u "$expected" "$actual" >&2 || true
        fail "$label"
    fi
}

invoke_zed() {
    local capture_file=$1
    local fish_command=$2
    shift 2

    env \
        "HOME=$TMP_DIR/home" \
        "PATH=$TMP_DIR/bin:$ORIGINAL_PATH" \
        "ZED_CAPTURE=$capture_file" \
        "ZED_FUNCTION=$FUNCTION_FILE" \
        "$@" \
        fish --no-config --command "source \"\$ZED_FUNCTION\"; $fish_command"
}

[[ -f "$FUNCTION_FILE" ]] || fail "missing $FUNCTION_FILE"

TMP_DIR=$(mktemp -d)
readonly TMP_DIR
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/home" "$TMP_DIR/workspace"
cat > "$TMP_DIR/bin/zed" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${ZED_CAPTURE:?}"
printf '%s\n' "$@" > "$ZED_CAPTURE"
exit "${ZED_EXIT_STATUS:-0}"
EOF
chmod +x "$TMP_DIR/bin/zed"

valid_workspace="$TMP_DIR/workspace/project.code-workspace"
absolute_root="$TMP_DIR/absolute root"
jq -n --arg absolute_root "$absolute_root" '
    {
        folders: [
            {path: "../relative root"},
            {path: $absolute_root},
            {path: "~/home root"}
        ]
    }
' > "$valid_workspace"

valid_capture="$TMP_DIR/valid.capture"
invoke_zed \
    "$valid_capture" \
    'zed "$TEST_WORKSPACE"' \
    "TEST_WORKSPACE=$valid_workspace"

printf '%s\n' \
    '-n' \
    "$TMP_DIR/relative root" \
    "$absolute_root" \
    "$TMP_DIR/home/home root" \
    > "$TMP_DIR/valid.expected"
assert_file_equals "$TMP_DIR/valid.expected" "$valid_capture" \
    "workspace roots were not passed to Zed correctly"

missing_workspace="$TMP_DIR/missing.code-workspace"
if invoke_zed \
    "$TMP_DIR/missing.capture" \
    'zed "$TEST_WORKSPACE"' \
    "TEST_WORKSPACE=$missing_workspace" \
    > "$TMP_DIR/missing.out" 2> "$TMP_DIR/missing.err"
then
    fail "missing workspace unexpectedly succeeded"
fi
grep -Fq "Workspace 不存在: $missing_workspace" "$TMP_DIR/missing.err" \
    || fail "missing workspace error was not reported"
[[ ! -e "$TMP_DIR/missing.capture" ]] \
    || fail "missing workspace invoked the real Zed command"

invalid_workspace="$TMP_DIR/workspace/invalid.code-workspace"
printf '{"folders": [{"path": "../relative root"},]}\n' > "$invalid_workspace"
if invoke_zed \
    "$TMP_DIR/invalid.capture" \
    'zed "$TEST_WORKSPACE"' \
    "TEST_WORKSPACE=$invalid_workspace" \
    > "$TMP_DIR/invalid.out" 2> "$TMP_DIR/invalid.err"
then
    fail "invalid workspace unexpectedly succeeded"
fi
grep -Fq "无法解析 workspace: $invalid_workspace" "$TMP_DIR/invalid.err" \
    || fail "invalid workspace error was not reported"
[[ ! -e "$TMP_DIR/invalid.capture" ]] \
    || fail "invalid workspace invoked the real Zed command"

empty_workspace="$TMP_DIR/workspace/empty.code-workspace"
printf '{"folders": []}\n' > "$empty_workspace"
if invoke_zed \
    "$TMP_DIR/empty.capture" \
    'zed "$TEST_WORKSPACE"' \
    "TEST_WORKSPACE=$empty_workspace" \
    > "$TMP_DIR/empty.out" 2> "$TMP_DIR/empty.err"
then
    fail "workspace without folders unexpectedly succeeded"
fi
grep -Fq 'Workspace 中没有有效的 folders[].path' "$TMP_DIR/empty.err" \
    || fail "empty workspace error was not reported"
[[ ! -e "$TMP_DIR/empty.capture" ]] \
    || fail "workspace without folders invoked the real Zed command"

passthrough_capture="$TMP_DIR/passthrough.capture"
passthrough_file="$TMP_DIR/file with spaces.txt"
invoke_zed \
    "$passthrough_capture" \
    'zed --wait "$TEST_FILE"' \
    "TEST_FILE=$passthrough_file"
printf '%s\n' '--wait' "$passthrough_file" > "$TMP_DIR/passthrough.expected"
assert_file_equals "$TMP_DIR/passthrough.expected" "$passthrough_capture" \
    "non-workspace arguments were not passed through unchanged"

if invoke_zed \
    "$TMP_DIR/status.capture" \
    'zed "$TEST_WORKSPACE"' \
    "TEST_WORKSPACE=$valid_workspace" \
    'ZED_EXIT_STATUS=23' \
    > "$TMP_DIR/status.out" 2> "$TMP_DIR/status.err"
then
    fail "Zed exit status was not propagated"
else
    status=$?
fi
[[ $status -eq 23 ]] || fail "expected Zed exit status 23, got $status"

printf 'PASS: zed workspace parsing, errors, passthrough, and exit status\n'
