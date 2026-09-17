#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FUNCTION_FILE="$ROOT_DIR/functions/fish_update.fish"
readonly ORIGINAL_PATH="$PATH"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local expected=$1
    local file=$2
    local label=$3
    grep -Fq -- "$expected" "$file" || fail "$label: missing '$expected'"
}

create_tagged_commit() {
    local payload=$1
    local timestamp=$2

    printf '%s\n' "$payload" > "$TMP_DIR/source/payload"
    git -C "$TMP_DIR/source" add payload
    git -C "$TMP_DIR/source" commit --quiet -m "$payload"

    local commit short_commit tag
    commit=$(git -C "$TMP_DIR/source" rev-parse HEAD)
    short_commit=$(git -C "$TMP_DIR/source" rev-parse --short=12 HEAD)
    tag="lemon-${timestamp}-g${short_commit}"
    git -C "$TMP_DIR/source" tag "$tag"
    git -C "$TMP_DIR/source" push --quiet origin HEAD:main "refs/tags/$tag"
    printf '%s\t%s\n' "$tag" "$commit"
}

invoke_fish_update() {
    local output=$1
    local command=$2
    shift 2

    env \
        "HOME=$TMP_DIR/home" \
        "PATH=$TMP_DIR/bin:$ORIGINAL_PATH" \
        "TMPDIR=$TMP_DIR/tmp" \
        "LEMON_FISH_REMOTE=$TMP_DIR/remote.git" \
        "LEMON_FISH_PREFIX=$TMP_DIR/install" \
        LEMON_FISH_NO_SUDO=1 \
        "FISH_UPDATE_FUNCTION=$FUNCTION_FILE" \
        "$@" \
        fish --no-config --command \
            'source "$FISH_UPDATE_FUNCTION"; fish_update '"$command" \
            > "$output" 2> "$output.err"
}

[[ -f "$FUNCTION_FILE" ]] || fail "missing $FUNCTION_FILE"
fish --no-config --no-execute "$FUNCTION_FILE" || fail "fish syntax check failed"

TMP_DIR=$(mktemp -d)
readonly TMP_DIR
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/home" "$TMP_DIR/tmp"
git init --quiet --bare "$TMP_DIR/remote.git"
git init --quiet "$TMP_DIR/source"
git -C "$TMP_DIR/source" config user.name test
git -C "$TMP_DIR/source" config user.email test@example.com
git -C "$TMP_DIR/source" remote add origin "$TMP_DIR/remote.git"
printf '[package]\nname = "fake-fish"\nversion = "0.0.0"\n' \
    > "$TMP_DIR/source/Cargo.toml"
git -C "$TMP_DIR/source" add Cargo.toml

cat > "$TMP_DIR/bin/cargo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${CARGO_TARGET_DIR:?}"
manifest=
while (($#)); do
    if [[ $1 == --manifest-path ]]; then
        manifest=$2
        shift 2
    else
        shift
    fi
done
[[ -n "$manifest" ]]

tag=$(git -C "$(dirname -- "$manifest")" describe --tags --exact-match HEAD)
mkdir -p "$CARGO_TARGET_DIR/release"
for binary in fish fish_indent fish_key_reader; do
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s test-%s"\n' \
        "$binary" "$tag" > "$CARGO_TARGET_DIR/release/$binary"
    chmod +x "$CARGO_TARGET_DIR/release/$binary"
done
EOF
chmod +x "$TMP_DIR/bin/cargo"

cat > "$TMP_DIR/bin/chsh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${CHSH_CAPTURE:?}"
printf '%s\n' "$@" > "$CHSH_CAPTURE"
EOF
chmod +x "$TMP_DIR/bin/chsh"

first_info=$(create_tagged_commit first 20260818T010000Z)
first_tag=${first_info%%$'\t'*}
first_commit=${first_info#*$'\t'}

invoke_fish_update "$TMP_DIR/check-first.out" check
assert_contains '已安装: 未安装 lemon fish' "$TMP_DIR/check-first.out" \
    'initial check did not report an empty installation'
assert_contains "远端最新: $first_tag" "$TMP_DIR/check-first.out" \
    'initial check selected the wrong tag'
assert_contains "提交: $first_commit" "$TMP_DIR/check-first.out" \
    'initial check selected the wrong commit'
assert_contains '状态: 有可用更新' "$TMP_DIR/check-first.out" \
    'initial check did not report an update'

invoke_fish_update "$TMP_DIR/upgrade-first.out" upgrade
assert_contains "安装完成: $first_tag" "$TMP_DIR/upgrade-first.out" \
    'first upgrade did not complete'
[[ $(readlink "$TMP_DIR/install/lib/lemon-fish/current") == "releases/$first_tag" ]] \
    || fail 'first upgrade selected the wrong release'
[[ $(readlink "$TMP_DIR/install/bin/fish") == '../lib/lemon-fish/current/fish' ]] \
    || fail 'fish command link is incorrect'
assert_contains "fish test-$first_tag" \
    "$TMP_DIR/install/lib/lemon-fish/releases/$first_tag/version" \
    'installed version metadata is incorrect'

invoke_fish_update "$TMP_DIR/check-current.out" check
assert_contains '状态: 已是最新' "$TMP_DIR/check-current.out" \
    'check did not recognize the installed tag'

second_info=$(create_tagged_commit second 20260818T020000Z)
second_tag=${second_info%%$'\t'*}

invoke_fish_update "$TMP_DIR/upgrade-second.out" upgrade
assert_contains "安装完成: $second_tag" "$TMP_DIR/upgrade-second.out" \
    'second upgrade did not complete'
[[ $(readlink "$TMP_DIR/install/lib/lemon-fish/current") == "releases/$second_tag" ]] \
    || fail 'second upgrade selected the wrong release'
[[ $(readlink "$TMP_DIR/install/lib/lemon-fish/previous") == "releases/$first_tag" ]] \
    || fail 'second upgrade did not preserve the previous release'

invoke_fish_update "$TMP_DIR/rollback.out" rollback
assert_contains "已回滚到: $first_tag" "$TMP_DIR/rollback.out" \
    'rollback did not select the first release'
[[ $(readlink "$TMP_DIR/install/lib/lemon-fish/current") == "releases/$first_tag" ]] \
    || fail 'rollback did not switch current atomically'
[[ $(readlink "$TMP_DIR/install/lib/lemon-fish/previous") == "releases/$second_tag" ]] \
    || fail 'rollback did not retain the replaced release'

invoke_fish_update "$TMP_DIR/status.out" status
assert_contains "当前 tag: $first_tag" "$TMP_DIR/status.out" \
    'status did not report the current release'
assert_contains "上一 tag: $second_tag" "$TMP_DIR/status.out" \
    'status did not report the previous release'
assert_contains "命令路径: $TMP_DIR/install/bin/fish" "$TMP_DIR/status.out" \
    'status did not report the managed binary'

invoke_fish_update \
    "$TMP_DIR/activate.out" \
    activate \
    "LEMON_FISH_SHELLS_FILE=$TMP_DIR/shells" \
    "CHSH_CAPTURE=$TMP_DIR/chsh.capture"
assert_contains "$TMP_DIR/install/bin/fish" "$TMP_DIR/shells" \
    'activate did not register the managed fish in shells'
printf '%s\n' '-s' "$TMP_DIR/install/bin/fish" "$(id -un)" \
    > "$TMP_DIR/chsh.expected"
cmp -s "$TMP_DIR/chsh.expected" "$TMP_DIR/chsh.capture" \
    || fail 'activate called chsh with unexpected arguments'

mkdir -p "$TMP_DIR/collision/bin"
printf 'do not replace\n' > "$TMP_DIR/collision/bin/fish"
if env \
    "HOME=$TMP_DIR/home" \
    "PATH=$TMP_DIR/bin:$ORIGINAL_PATH" \
    "TMPDIR=$TMP_DIR/tmp" \
    "LEMON_FISH_REMOTE=$TMP_DIR/remote.git" \
    "LEMON_FISH_PREFIX=$TMP_DIR/collision" \
    LEMON_FISH_NO_SUDO=1 \
    "FISH_UPDATE_FUNCTION=$FUNCTION_FILE" \
    fish --no-config --command \
        'source "$FISH_UPDATE_FUNCTION"; fish_update upgrade' \
        > "$TMP_DIR/collision.out" 2> "$TMP_DIR/collision.err"
then
    fail 'upgrade unexpectedly replaced an existing binary'
fi
assert_contains "拒绝覆盖已有文件: $TMP_DIR/collision/bin/fish" \
    "$TMP_DIR/collision.err" 'collision guard did not explain the refusal'
assert_contains 'do not replace' "$TMP_DIR/collision/bin/fish" \
    'collision guard modified the existing binary'

if find "$TMP_DIR/tmp" -mindepth 1 -print -quit | grep -q .; then
    fail 'fish_update left a temporary build directory behind'
fi

printf 'PASS: fish_update check, upgrade, status, activate, rollback, and collision guard\n'
