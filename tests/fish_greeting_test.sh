#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FUNCTION_FILE="$ROOT_DIR/functions/fish_greeting.fish"
readonly TRUECOLOR_SHA256="b95e5598fffcac61a4a10bbf185fe602068e4b7ed6e8de3caf0cb9308060a28e"
readonly XTERM256_SHA256="3dcd1dec206d85cfc5855d74f16df3be3f4877528befcd469ebc5e50d111cf88"
readonly PLAIN_SHA256="4827bd4b6fbdb09ea318d017d7c7c58ba786ef5faf48dfcd3de0943070e335c6"
readonly TITLE_TRUECOLOR_SHA256="ce4807ba3b2f2c0445cce339b5683df975b1eca12154ac230e94e30c774437b2"
readonly TITLE_PLAIN_SHA256="758a85557c85abb981dffa7763223ed926e5d2faf6f8200d47112c28e15c2acd"
readonly LEMON_TRUECOLOR_SHA256="a768dcc6b1a9ff91d053ff48c4e8eb1c97ed287bde924803512b7f1f7cf31247"
readonly LEMON_PLAIN_SHA256="fc917acdb5302983b470eb4d8cd3e83e68e2c6f3da246b2ad3e89bc14d2c0ae2"
readonly FISH_COMMAND='source "$GREETING_FUNCTION"; fish_greeting'

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

hash_file() {
    sha256sum "$1" | awk '{print $1}'
}

assert_hash() {
    local expected=$1
    local file=$2
    local label=$3
    local actual
    actual=$(hash_file "$file")
    [[ "$actual" == "$expected" ]] || fail "$label hash: expected $expected, got $actual"
}

assert_empty() {
    local file=$1
    local label=$2
    [[ ! -s "$file" ]] || fail "$label produced $(wc -c < "$file") bytes"
}

capture_pty() {
    local mode=$1
    local destination="$TMP_DIR/$mode.out"
    case "$mode" in
        truecolor)
            GREETING_FUNCTION="$FUNCTION_FILE" script -qfec \
                "env TERM=xterm-256color COLORTERM=truecolor fish --no-config --interactive --command '$FISH_COMMAND' 2>/dev/null" \
                /dev/null > "$destination.pty"
            ;;
        term_truecolor)
            GREETING_FUNCTION="$FUNCTION_FILE" script -qfec \
                "env -u COLORTERM TERM=xterm-direct fish --no-config --interactive --command '$FISH_COMMAND' 2>/dev/null" \
                /dev/null > "$destination.pty"
            ;;
        xterm256)
            GREETING_FUNCTION="$FUNCTION_FILE" script -qfec \
                "env -u COLORTERM TERM=xterm-256color fish --no-config --interactive --command '$FISH_COMMAND' 2>/dev/null" \
                /dev/null > "$destination.pty"
            ;;
        dumb)
            GREETING_FUNCTION="$FUNCTION_FILE" script -qfec \
                "env TERM=dumb COLORTERM=truecolor fish --no-config --interactive --command '$FISH_COMMAND' 2>/dev/null" \
                /dev/null > "$destination.pty"
            ;;
        *)
            fail "unknown capture mode: $mode"
            ;;
    esac
    tr -d '\r' < "$destination.pty" > "$destination"
    printf '%s\n' "$destination"
}

split_safety_reset() {
    local output=$1
    local payload=$2
    local reset="$TMP_DIR/reset.bin"
    printf '\033[0m' > "$reset"
    [[ $(wc -c < "$output") -ge 4 ]] || fail "output is shorter than the safety reset"
    tail -c 4 "$output" | cmp -s - "$reset" || fail "output does not end with ESC[0m"
    head -c -4 "$output" > "$payload"
}

strip_sgr() {
    perl -pe 's/\e\[[0-9;]*m//g' "$1" > "$2"
}

[[ -f "$FUNCTION_FILE" ]] || fail "missing $FUNCTION_FILE"
fish -n "$FUNCTION_FILE" || fail "fish syntax check failed"

TMP_DIR=$(mktemp -d)
readonly TMP_DIR
trap 'rm -rf "$TMP_DIR"' EXIT

GREETING_FUNCTION="$FUNCTION_FILE" env TERM=xterm-256color COLORTERM=truecolor \
    fish --no-config --command "$FISH_COMMAND" > "$TMP_DIR/noninteractive.out"
assert_empty "$TMP_DIR/noninteractive.out" "non-interactive invocation"

GREETING_FUNCTION="$FUNCTION_FILE" env TERM=xterm-256color COLORTERM=truecolor \
    fish --no-config --interactive --command "$FISH_COMMAND" \
    > "$TMP_DIR/notty.out" 2>/dev/null
assert_empty "$TMP_DIR/notty.out" "non-TTY invocation"

dumb_output=$(capture_pty dumb)
assert_empty "$dumb_output" "TERM=dumb invocation"

truecolor_output=$(capture_pty truecolor)
term_truecolor_output=$(capture_pty term_truecolor)
xterm256_output=$(capture_pty xterm256)
split_safety_reset "$truecolor_output" "$TMP_DIR/truecolor.payload"
split_safety_reset "$term_truecolor_output" "$TMP_DIR/term-truecolor.payload"
split_safety_reset "$xterm256_output" "$TMP_DIR/xterm256.payload"

assert_hash "$TRUECOLOR_SHA256" "$TMP_DIR/truecolor.payload" "truecolor payload"
assert_hash "$TRUECOLOR_SHA256" "$TMP_DIR/term-truecolor.payload" "TERM truecolor payload"
assert_hash "$XTERM256_SHA256" "$TMP_DIR/xterm256.payload" "xterm-256 payload"

strip_sgr "$TMP_DIR/truecolor.payload" "$TMP_DIR/truecolor.txt"
strip_sgr "$TMP_DIR/xterm256.payload" "$TMP_DIR/xterm256.txt"
assert_hash "$PLAIN_SHA256" "$TMP_DIR/truecolor.txt" "truecolor plain text"
assert_hash "$PLAIN_SHA256" "$TMP_DIR/xterm256.txt" "xterm-256 plain text"
cmp -s "$TMP_DIR/truecolor.txt" "$TMP_DIR/xterm256.txt" || fail "color modes changed the character matrix"

head -n 6 "$TMP_DIR/truecolor.payload" > "$TMP_DIR/title.ansi"
head -n 6 "$TMP_DIR/truecolor.txt" > "$TMP_DIR/title.txt"
sed -n '8,31p' "$TMP_DIR/truecolor.payload" | cut -c 5- > "$TMP_DIR/lemon.ansi"
sed -n '8,31p' "$TMP_DIR/truecolor.txt" | cut -c 5- > "$TMP_DIR/lemon.txt"
assert_hash "$TITLE_TRUECOLOR_SHA256" "$TMP_DIR/title.ansi" "title ANSI"
assert_hash "$TITLE_PLAIN_SHA256" "$TMP_DIR/title.txt" "title plain text"
assert_hash "$LEMON_TRUECOLOR_SHA256" "$TMP_DIR/lemon.ansi" "lemon ANSI"
assert_hash "$LEMON_PLAIN_SHA256" "$TMP_DIR/lemon.txt" "lemon plain text"

awk '
    NR <= 6 && length($0) > 71 { exit 1 }
    NR == 7 && length($0) != 0 { exit 1 }
    NR >= 8 && NR <= 31 && (length($0) != 68 || substr($0, 1, 4) != "    ") { exit 1 }
    END { if (NR != 31) exit 1 }
' "$TMP_DIR/truecolor.txt" || fail "plain-text layout is not 6 + 1 + 24 lines within 71 columns"

if LC_ALL=C grep -n '[^ .=+#@-]' "$TMP_DIR/lemon.txt"; then
    fail "lemon contains a character outside space and .-=+#@"
fi

LC_ALL=C grep -aFq $'\033[38;2;' "$TMP_DIR/truecolor.payload" || fail "truecolor payload has no 24-bit SGR"
LC_ALL=C grep -aFq $'\033[38;5;' "$TMP_DIR/xterm256.payload" || fail "xterm-256 payload has no 256-color SGR"
if LC_ALL=C grep -aFq $'\033[38;2;' "$TMP_DIR/xterm256.payload"; then
    fail "xterm-256 payload still contains 24-bit SGR"
fi

printf 'PASS: fish_greeting syntax, guards, hashes, layout, reset, and color fallback\n'
