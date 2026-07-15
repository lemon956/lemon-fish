# oh-lemon-fish 启动欢迎画面实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Fish 原生 `fish_greeting` 更新为在安全的交互式 TTY 中打印已批准的 Doom 右倾彩虹标题和 64×20 真彩柠檬，并提供字符布局不变的 xterm-256 降级。

**Architecture:** 运行时只有 `functions/fish_greeting.fish`：先执行交互式、TTY 和 `TERM=dumb` 守卫，再从两个静态 ANSI 负载中选择真彩或 256 色版本，最后追加不换行的安全重置。批准的真彩负载在开发阶段由临时生成器编码进 Fish 源文件；生成器同时确定性地产生 xterm-256 负载，启动时不读取图片、不转换字符画，也不启动外部进程。

**Tech Stack:** Fish 4.6.0、Bash、Python 3 标准库（仅开发期临时生成器）、util-linux `script` 2.41.3、GNU coreutils、Perl。

## Global Constraints

- 规格来源：`docs/superpowers/specs/2026-07-14-oh-lemon-fish-greeting-design.md`。
- 唯一运行时文件是 `functions/fish_greeting.fish`；不得修改 `config.fish`、`conf.d/`、提示符或通用颜色变量。
- 真彩批准负载必须来自 `/tmp/oh-lemon-fish-doom-slanted-color-preview-64x20.ansi`，其 SHA-256 必须为 `2e244f260807929ff832145ed36d2262d670ca78b9940bf88c1d533e8b554b53`；若文件缺失或哈希不符，停止并要求恢复批准产物，不得凭近似预览重建。
- xterm-256 负载必须由同一 RGB 单元映射到 xterm 16–255 调色板，SHA-256 必须为 `c3cc4c65c18c0e7e8a2a2f70566074ca66a7f412241badc3e9a8aba9cace68ca`。
- 两个颜色负载剥离 ANSI 后必须完全一致，纯文本 SHA-256 必须为 `727e5386d9a04a74376ee9d3fa57f849d80b823429bd9c3d5e1fc3c15942d975`。
- 可见结构固定为 6 行标题、1 行空行、20 行柠檬；最大宽度 71 列；柠檬每行由 4 个缩进空格和 64 列负载组成。
- 真彩标题 ANSI、标题纯文本、柠檬 ANSI、柠檬纯文本 SHA-256 分别为 `ce4807ba3b2f2c0445cce339b5683df975b1eca12154ac230e94e30c774437b2`、`758a85557c85abb981dffa7763223ed926e5d2faf6f8200d47112c28e15c2acd`、`548cda3b81ed28b0e309fb10c5040a317b645581cd3b86116b7dbe1bd817b989`、`baa279ead94a62b694a474e64ee3b16457a4a6b3445ad3cd74a4b7c1393363b1`。
- 非交互式 Fish、非 TTY 和 `TERM=dumb` 必须安静成功返回；任何可见输出路径都必须以单个、不换行的 `ESC[0m` 安全重置结束。
- 运行时只使用 Fish 内建命令及内嵌函数 `isatty`；不得调用 `cat`、Python、ImageMagick、Chafa、FIGlet、PyFiglet、`ascii-image-converter` 或其他外部进程。
- 同一 Fish 进程内连续调用 20 次的中位耗时必须不超过 50 ms。

## File Structure

- Modify `functions/fish_greeting.fish`: 唯一运行时单元，负责守卫、颜色能力选择、静态负载和最终重置。
- Modify `tests/fish_greeting_test.sh`: 开发期字节级验收脚本，负责 PTY 捕获、哈希、布局、字符集、颜色分支和静默守卫验证。
- Temporary `/tmp/build_fish_greeting.py`: 不提交；把已批准真彩负载转换成 Fish 安全静态字面量并生成 256 色副本。

---

### Task 1: 更新并自动验收静态欢迎画面

**Files:**
- Modify: `functions/fish_greeting.fish`
- Modify: `tests/fish_greeting_test.sh`
- Reference: `docs/superpowers/specs/2026-07-14-oh-lemon-fish-greeting-design.md`
- Temporary: `/tmp/build_fish_greeting.py`

**Interfaces:**
- Consumes: 已批准的 `/tmp/oh-lemon-fish-doom-slanted-color-preview-64x20.ansi` 真彩负载及规格中的固定哈希。
- Produces: `fish_greeting`（无参数；仅在交互式 TTY 且 `TERM != dumb` 时向标准输出写入负载）；`bash tests/fish_greeting_test.sh`（成功返回 0，失败返回非 0 并输出精确原因）。

- [ ] **Step 1: 验证实现前置条件**

Run:

```bash
test -f /tmp/oh-lemon-fish-doom-slanted-color-preview-64x20.ansi
test "$(sha256sum /tmp/oh-lemon-fish-doom-slanted-color-preview-64x20.ansi | awk '{print $1}')" = \
  2e244f260807929ff832145ed36d2262d670ca78b9940bf88c1d533e8b554b53
test -f functions/fish_greeting.fish
fish --version
script --version | sed -n '1p'
```

Expected: 三个 `test` 均返回 0；版本输出包含 `fish, version 4.6.0` 和 `script from util-linux 2.41.3`。

- [ ] **Step 2: 写入失败优先的字节级验收脚本**

Update `tests/fish_greeting_test.sh` to this complete content:

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FUNCTION_FILE="$ROOT_DIR/functions/fish_greeting.fish"
readonly TRUECOLOR_SHA256="2e244f260807929ff832145ed36d2262d670ca78b9940bf88c1d533e8b554b53"
readonly XTERM256_SHA256="c3cc4c65c18c0e7e8a2a2f70566074ca66a7f412241badc3e9a8aba9cace68ca"
readonly PLAIN_SHA256="727e5386d9a04a74376ee9d3fa57f849d80b823429bd9c3d5e1fc3c15942d975"
readonly TITLE_TRUECOLOR_SHA256="ce4807ba3b2f2c0445cce339b5683df975b1eca12154ac230e94e30c774437b2"
readonly TITLE_PLAIN_SHA256="758a85557c85abb981dffa7763223ed926e5d2faf6f8200d47112c28e15c2acd"
readonly LEMON_TRUECOLOR_SHA256="548cda3b81ed28b0e309fb10c5040a317b645581cd3b86116b7dbe1bd817b989"
readonly LEMON_PLAIN_SHA256="baa279ead94a62b694a474e64ee3b16457a4a6b3445ad3cd74a4b7c1393363b1"
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
sed -n '8,27p' "$TMP_DIR/truecolor.payload" | cut -c 5- > "$TMP_DIR/lemon.ansi"
sed -n '8,27p' "$TMP_DIR/truecolor.txt" | cut -c 5- > "$TMP_DIR/lemon.txt"
assert_hash "$TITLE_TRUECOLOR_SHA256" "$TMP_DIR/title.ansi" "title ANSI"
assert_hash "$TITLE_PLAIN_SHA256" "$TMP_DIR/title.txt" "title plain text"
assert_hash "$LEMON_TRUECOLOR_SHA256" "$TMP_DIR/lemon.ansi" "lemon ANSI"
assert_hash "$LEMON_PLAIN_SHA256" "$TMP_DIR/lemon.txt" "lemon plain text"

awk '
    NR <= 6 && length($0) > 71 { exit 1 }
    NR == 7 && length($0) != 0 { exit 1 }
    NR >= 8 && NR <= 27 && (length($0) != 68 || substr($0, 1, 4) != "    ") { exit 1 }
    END { if (NR != 27) exit 1 }
' "$TMP_DIR/truecolor.txt" || fail "plain-text layout is not 6 + 1 + 20 lines within 71 columns"

if LC_ALL=C grep -n '[^ .=+#@-]' "$TMP_DIR/lemon.txt"; then
    fail "lemon contains a character outside space and .-=+#@"
fi

LC_ALL=C grep -aFq $'\033[38;2;' "$TMP_DIR/truecolor.payload" || fail "truecolor payload has no 24-bit SGR"
LC_ALL=C grep -aFq $'\033[38;5;' "$TMP_DIR/xterm256.payload" || fail "xterm-256 payload has no 256-color SGR"
if LC_ALL=C grep -aFq $'\033[38;2;' "$TMP_DIR/xterm256.payload"; then
    fail "xterm-256 payload still contains 24-bit SGR"
fi

printf 'PASS: fish_greeting syntax, guards, hashes, layout, reset, and color fallback\n'
```

Make it executable:

```bash
chmod +x tests/fish_greeting_test.sh
```

- [ ] **Step 3: 运行验收脚本并确认旧负载不满足新合同**

Run:

```bash
bash tests/fish_greeting_test.sh
```

Expected: FAIL with the new truecolor payload hash as `expected` and the old 64×24 payload hash as `got`, with a non-zero exit status.

- [ ] **Step 4: 写入开发期临时生成器**

Create `/tmp/build_fish_greeting.py` with this complete content. This file is deliberately temporary: the binary ANSI payload is large, while the committed runtime must remain one Fish function with no generator dependency.

```python
#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

TRUECOLOR_SHA256 = "2e244f260807929ff832145ed36d2262d670ca78b9940bf88c1d533e8b554b53"
XTERM256_SHA256 = "c3cc4c65c18c0e7e8a2a2f70566074ca66a7f412241badc3e9a8aba9cace68ca"
PLAIN_SHA256 = "727e5386d9a04a74376ee9d3fa57f849d80b823429bd9c3d5e1fc3c15942d975"
SGR = re.compile(rb"\x1b\[[0-9;]*m")


def xterm_palette() -> list[tuple[int, int, int, int]]:
    palette: list[tuple[int, int, int, int]] = []
    for index in range(16, 232):
        value = index - 16
        levels = (value // 36, (value // 6) % 6, value % 6)
        rgb = tuple(0 if level == 0 else 55 + 40 * level for level in levels)
        palette.append((index, *rgb))
    for index in range(232, 256):
        level = 8 + 10 * (index - 232)
        palette.append((index, level, level, level))
    return palette


def to_xterm256(payload: bytes) -> bytes:
    palette = xterm_palette()

    def replace(match: re.Match[bytes]) -> bytes:
        red, green, blue = (int(value) for value in match.groups())
        index = min(
            palette,
            key=lambda color: (
                (color[1] - red) ** 2
                + (color[2] - green) ** 2
                + (color[3] - blue) ** 2,
                color[0],
            ),
        )[0]
        return f"\x1b[38;5;{index}m".encode()

    return re.sub(rb"\x1b\[38;2;(\d+);(\d+);(\d+)m", replace, payload)


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def require_hash(label: str, payload: bytes, expected: str) -> None:
    actual = sha256(payload)
    if actual != expected:
        raise SystemExit(f"unexpected {label} hash: expected {expected}, got {actual}")


def fish_escape(payload: bytes) -> str:
    result = subprocess.run(
        [
            "fish",
            "--no-config",
            "--command",
            "read --null value; and string escape --style=script -- $value",
        ],
        input=payload,
        check=True,
        stdout=subprocess.PIPE,
    )
    return result.stdout.decode().removesuffix("\n")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} APPROVED_ANSI OUTPUT_FISH")

    source = Path(sys.argv[1])
    destination = Path(sys.argv[2])
    truecolor = source.read_bytes()
    require_hash("truecolor payload", truecolor, TRUECOLOR_SHA256)
    require_hash("plain payload", SGR.sub(b"", truecolor), PLAIN_SHA256)

    xterm256 = to_xterm256(truecolor)
    require_hash("xterm-256 payload", xterm256, XTERM256_SHA256)
    require_hash("xterm-256 plain payload", SGR.sub(b"", xterm256), PLAIN_SHA256)

    truecolor_token = fish_escape(truecolor)
    xterm256_token = fish_escape(xterm256)
    destination.write_text(
        "function fish_greeting --description 'Show the oh-lemon-fish startup greeting'\n"
        "    status is-interactive\n"
        "    or return 0\n\n"
        "    isatty stdout\n"
        "    or return 0\n\n"
        "    if set -q TERM; and test \"$TERM\" = dumb\n"
        "        return 0\n"
        "    end\n\n"
        "    set -l _use_truecolor 0\n"
        "    if set -q COLORTERM; and string match --quiet --ignore-case --regex '^(truecolor|24bit)$' -- \"$COLORTERM\"\n"
        "        set _use_truecolor 1\n"
        "    else if set -q TERM; and string match --quiet --ignore-case --regex '(-direct|-truecolor|-24bit)$' -- \"$TERM\"\n"
        "        set _use_truecolor 1\n"
        "    end\n\n"
        "    set -l _payload\n"
        "    if test $_use_truecolor -eq 1\n"
        f"        set _payload {truecolor_token}\n"
        "    else\n"
        f"        set _payload {xterm256_token}\n"
        "    end\n\n"
        "    printf '%s\\e[0m' \"$_payload\"\n"
        "end\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: 生成最小 Fish 实现并进行语法检查**

Run:

```bash
python3 /tmp/build_fish_greeting.py \
  /tmp/oh-lemon-fish-doom-slanted-color-preview-64x20.ansi \
  functions/fish_greeting.fish
fish -n functions/fish_greeting.fish
test "$(wc -c < functions/fish_greeting.fish)" -eq 51457
rm /tmp/build_fish_greeting.py
```

Expected: generator and `fish -n` return 0; generated source is exactly 51,457 bytes on Fish 4.6.0; the temporary generator is removed.

- [ ] **Step 6: 运行完整自动验收**

Run:

```bash
bash tests/fish_greeting_test.sh
```

Expected:

```text
PASS: fish_greeting syntax, guards, hashes, layout, reset, and color fallback
```

- [ ] **Step 7: 审计运行时依赖和差异范围**

Run:

```bash
fish -n functions/fish_greeting.fish
if rg -n '(^|[[:space:]])(cat|python3?|magick|chafa|figlet|pyfiglet|ascii-image-converter|base64)([[:space:]]|$)' \
  functions/fish_greeting.fish; then
  exit 1
fi
git diff --check
git status --short
```

Expected: syntax and dependency audit return 0; `git diff --check` is silent; status lists the runtime function, acceptance script, design spec, and implementation plan.

- [ ] **Step 8: 提交 64×20 定稿修改**

```bash
git add functions/fish_greeting.fish tests/fish_greeting_test.sh \
  docs/superpowers/specs/2026-07-14-oh-lemon-fish-greeting-design.md \
  docs/superpowers/plans/2026-07-15-oh-lemon-fish-greeting.md
git commit -m "feat: flatten oh-lemon-fish greeting"
```

Expected: one commit containing exactly the runtime function, acceptance script, design spec, and implementation plan.

### Task 2: 执行真实终端与性能验收

**Files:**
- Verify: `functions/fish_greeting.fish`
- Verify: `tests/fish_greeting_test.sh`

**Interfaces:**
- Consumes: Task 1 生成的 `fish_greeting` 和 `tests/fish_greeting_test.sh`。
- Produces: 真彩、256 色、静默守卫、视觉、提示符重置及 20 次同进程性能的验收证据；不产生新的仓库文件。

- [ ] **Step 1: 重跑可重复的自动验收**

Run:

```bash
bash tests/fish_greeting_test.sh
```

Expected: the single `PASS: fish_greeting syntax, guards, hashes, layout, reset, and color fallback` line.

- [ ] **Step 2: 在真彩 PTY 中人工核对最终画面**

Run this command with a real PTY:

```bash
env TERM=xterm-256color COLORTERM=truecolor \
  fish --no-config --interactive --command \
  'source functions/fish_greeting.fish; fish_greeting'
```

Expected: 6 行 Doom 轻度右倾彩虹标题、1 行空行和 20 行居中柠檬；`oh-lemon-fish` 易读，整果、切面和叶子可辨认，命令结束后终端颜色恢复正常。

- [ ] **Step 3: 在 xterm-256 PTY 中人工核对降级画面**

Run this command with a real PTY:

```bash
env -u COLORTERM TERM=xterm-256color \
  fish --no-config --interactive --command \
  'source functions/fish_greeting.fish; fish_greeting'
```

Expected: 字符、行数和缩进与真彩画面完全相同；标题仍呈彩虹变化，黄色果实、浅色切面和绿色叶片仍可区分。

- [ ] **Step 4: 验证 20 次同进程调用的中位耗时**

Run from the repository root:

```bash
set -euo pipefail
perf_tmp=$(mktemp -d)
trap 'rm -rf "$perf_tmp"' EXIT
capture="$perf_tmp/fish-time.pty"
raw="$perf_tmp/time.raw"
samples="$perf_tmp/time-ms.txt"

script -qfec "env TERM=xterm-256color COLORTERM=truecolor fish --no-config --interactive --command 'source functions/fish_greeting.fish; for i in (seq 20); time fish_greeting; end'" \
  /dev/null > "$capture"

tr -d '\r' < "$capture" |
  awk '$1 == "Executed" && $2 == "in" { print }' > "$raw"
awk '
  function milliseconds(value, unit) {
    if (unit == "micros") return value / 1000
    if (unit == "millis") return value
    if (unit == "secs") return value * 1000
    printf "unsupported Fish time unit: %s\n", unit > "/dev/stderr"
    exit 2
  }
  { printf "%.6f\n", milliseconds($3, $4) }
' "$raw" > "$samples"

printf '%s\n' 'raw_samples:'
nl -ba "$raw"
printf '%s\n' 'normalized_samples_ms:'
nl -ba "$samples"
sort -n "$samples" | awk '
  NR == 1 { minimum = $1 }
  NR == 10 { lower = $1 }
  NR == 11 { upper = $1 }
  { maximum = $1 }
  END {
    if (NR != 20) {
      printf "samples=%d expected=20\n", NR > "/dev/stderr"
      exit 1
    }
    median = (lower + upper) / 2
    printf "samples=%d median_ms=%.3f min_ms=%.3f max_ms=%.3f\n", NR, median, minimum, maximum
    exit !(median <= 50)
  }
'

rm -rf "$perf_tmp"
trap - EXIT
```

Expected: `raw_samples` contains exactly 20 Fish `Executed in` lines with explicit `micros`, `millis`, or `secs` units; `normalized_samples_ms` contains exactly 20 millisecond values; the summary reports `samples=20` and `median_ms` at most `50.000`; command returns 0. On the inspected host, the corrected measurement reported `samples=20 median_ms=5.390 min_ms=5.320 max_ms=9.050`.

- [ ] **Step 5: 确认最终仓库状态**

Run:

```bash
git status --short
git log -5 --oneline --decorate
```

Expected: status is empty; the 64×20 finalization commit is at `HEAD` above the original feature and design commits. This task is verification-only and creates no additional commit.
