function __lemon_fish_update_setting --argument-names variable fallback
    if set -q $variable
        echo $$variable
    else
        echo $fallback
    end
end

function __lemon_fish_update_latest
    set -l remote (__lemon_fish_update_setting LEMON_FISH_REMOTE https://github.com/lemon956/fish-shell.git)
    set -l tag_prefix lemon-
    set -l refs (command git ls-remote --tags --refs "$remote" "refs/tags/$tag_prefix*" 2>/dev/null)
    set -l git_status $status

    if test $git_status -ne 0
        echo "无法查询 fish fork: $remote" >&2
        return $git_status
    end

    if test (count $refs) -eq 0
        echo "fish fork 尚无 $tag_prefix 开头的更新 tag" >&2
        return 1
    end

    set -l latest_line (printf '%s\n' $refs | command sort -k2,2 | command tail -n 1)
    set -l fields (string split \t -- "$latest_line")
    if test (count $fields) -ne 2
        echo "无法解析 fish fork 的 tag 信息" >&2
        return 1
    end

    set -l commit $fields[1]
    set -l tag (string replace 'refs/tags/' '' -- $fields[2])
    if not string match --quiet --regex '^lemon-[0-9]{8}T[0-9]{6}Z-g[0-9a-f]{12}$' -- $tag
        echo "fish fork 返回了不符合约定的 tag: $tag" >&2
        return 1
    end
    if not string match --quiet --regex '^[0-9a-f]{40}$' -- $commit
        echo "fish fork 返回了无效的提交: $commit" >&2
        return 1
    end

    printf '%s\t%s\n' $tag $commit
end

function __lemon_fish_update_current_tag
    set -l prefix (__lemon_fish_update_setting LEMON_FISH_PREFIX /usr/local)
    set -l current_link "$prefix/lib/lemon-fish/current"

    if not test -L "$current_link"
        return 1
    end

    set -l target (command readlink -- "$current_link")
    or return 1
    command basename -- "$target"
end

function __lemon_fish_update_as_root
    if test (command id -u) -eq 0; or set -q LEMON_FISH_NO_SUDO
        command $argv
        return $status
    end

    if not type --query sudo
        echo "需要写入安装目录，但系统中没有 sudo" >&2
        return 1
    end
    command sudo -- $argv
end

function __lemon_fish_update_cleanup --argument-names temporary_directory
    if test -z "$temporary_directory"; or not test -d "$temporary_directory"
        return
    end
    if not string match --quiet 'lemon-fish-update.*' -- (command basename -- "$temporary_directory")
        echo "拒绝清理非 fish_update 临时目录: $temporary_directory" >&2
        return 1
    end
    if not test -f "$temporary_directory/.lemon-fish-update-temp"
        echo "拒绝清理没有安全标记的临时目录: $temporary_directory" >&2
        return 1
    end
    command rm -rf -- "$temporary_directory"
end

function __lemon_fish_update_validate_links --argument-names prefix
    for binary in fish fish_indent fish_key_reader
        set -l link "$prefix/bin/$binary"
        set -l expected "../lib/lemon-fish/current/$binary"
        if test -L "$link"
            set -l actual (command readlink -- "$link")
            if test "$actual" != "$expected"
                echo "拒绝覆盖非 lemon-fish 链接: $link -> $actual" >&2
                return 1
            end
        else if test -e "$link"
            echo "拒绝覆盖已有文件: $link" >&2
            return 1
        end
    end
end

function __lemon_fish_update_switch_link --argument-names link target
    set -l next_link "$link.next.$fish_pid"
    __lemon_fish_update_as_root ln -sfn -- "$target" "$next_link"
    or return $status
    __lemon_fish_update_as_root mv -Tf -- "$next_link" "$link"
end

function __lemon_fish_update_upgrade
    for dependency in git cargo install mktemp
        if not type --query $dependency
            echo "缺少构建依赖: $dependency" >&2
            return 1
        end
    end
    if not type --query msgfmt
        echo "缺少构建依赖: msgfmt（Fedora 请安装 gettext）" >&2
        return 1
    end

    set -l latest (__lemon_fish_update_latest)
    or return $status
    set -l fields (string split \t -- "$latest")
    set -l tag $fields[1]
    set -l commit $fields[2]
    set -l current_tag (__lemon_fish_update_current_tag)
    if test "$current_tag" = "$tag"
        echo "已经是最新版本: $tag"
        return
    end

    set -l remote (__lemon_fish_update_setting LEMON_FISH_REMOTE https://github.com/lemon956/fish-shell.git)
    set -l prefix (__lemon_fish_update_setting LEMON_FISH_PREFIX /usr/local)
    set -l library "$prefix/lib/lemon-fish"
    set -l releases "$library/releases"
    set -l release "$releases/$tag"
    set -l temporary_directory (command mktemp -d -t lemon-fish-update.XXXXXX)
    or return $status
    command touch "$temporary_directory/.lemon-fish-update-temp"
    set -l source_directory "$temporary_directory/source"
    set -l target_directory "$temporary_directory/target"
    set -l stage_directory "$temporary_directory/release"

    echo "正在获取: $tag"
    command git clone --quiet --depth 1 --branch "$tag" -- "$remote" "$source_directory"
    or begin
        set -l operation_status $status
        __lemon_fish_update_cleanup "$temporary_directory"
        return $operation_status
    end

    set -l cloned_commit (command git -C "$source_directory" rev-parse HEAD)
    if test "$cloned_commit" != "$commit"
        echo "tag 提交校验失败: 预期 $commit，实际 $cloned_commit" >&2
        __lemon_fish_update_cleanup "$temporary_directory"
        return 1
    end

    echo "正在构建 fish（首次构建会下载 Rust 依赖）..."
    command env CARGO_TARGET_DIR="$target_directory" cargo build \
        --manifest-path "$source_directory/Cargo.toml" \
        --release --locked --bins
    or begin
        set -l operation_status $status
        __lemon_fish_update_cleanup "$temporary_directory"
        return $operation_status
    end

    command mkdir "$stage_directory"
    for binary in fish fish_indent fish_key_reader
        set -l built_binary "$target_directory/release/$binary"
        if not test -x "$built_binary"
            echo "构建结果缺少: $built_binary" >&2
            __lemon_fish_update_cleanup "$temporary_directory"
            return 1
        end
        command install -m 0755 -- "$built_binary" "$stage_directory/$binary"
        or begin
            set -l operation_status $status
            __lemon_fish_update_cleanup "$temporary_directory"
            return $operation_status
        end
    end
    printf '%s\n' "$commit" > "$stage_directory/commit"
    "$stage_directory/fish" --version > "$stage_directory/version"
    or begin
        set -l operation_status $status
        __lemon_fish_update_cleanup "$temporary_directory"
        return $operation_status
    end

    __lemon_fish_update_validate_links "$prefix"
    or begin
        set -l operation_status $status
        __lemon_fish_update_cleanup "$temporary_directory"
        return $operation_status
    end
    __lemon_fish_update_as_root mkdir -p -- "$prefix/bin" "$releases"
    or begin
        set -l operation_status $status
        __lemon_fish_update_cleanup "$temporary_directory"
        return $operation_status
    end

    if test -d "$release"
        set -l installed_commit (command cat "$release/commit" 2>/dev/null)
        if test "$installed_commit" != "$commit"
            echo "安装目录中的同名 tag 指向另一提交: $release" >&2
            __lemon_fish_update_cleanup "$temporary_directory"
            return 1
        end
    else
        __lemon_fish_update_as_root cp -a --no-preserve=ownership -- "$stage_directory" "$release"
        or begin
            set -l operation_status $status
            __lemon_fish_update_cleanup "$temporary_directory"
            return $operation_status
        end
    end

    if test -L "$library/current"
        set -l old_target (command readlink -- "$library/current")
        __lemon_fish_update_switch_link "$library/previous" "$old_target"
        or begin
            set -l operation_status $status
            __lemon_fish_update_cleanup "$temporary_directory"
            return $operation_status
        end
    end
    __lemon_fish_update_switch_link "$library/current" "releases/$tag"
    or begin
        set -l operation_status $status
        __lemon_fish_update_cleanup "$temporary_directory"
        return $operation_status
    end

    for binary in fish fish_indent fish_key_reader
        set -l link "$prefix/bin/$binary"
        if not test -L "$link"
            __lemon_fish_update_as_root ln -s -- "../lib/lemon-fish/current/$binary" "$link"
            or begin
                set -l operation_status $status
                __lemon_fish_update_cleanup "$temporary_directory"
                return $operation_status
            end
        end
    end

    set -l installed_version (string trim < "$release/version")
    __lemon_fish_update_cleanup "$temporary_directory"
    echo "安装完成: $tag"
    echo "版本: $installed_version"
    echo "路径: $prefix/bin/fish"
end

function __lemon_fish_update_rollback
    set -l prefix (__lemon_fish_update_setting LEMON_FISH_PREFIX /usr/local)
    set -l library "$prefix/lib/lemon-fish"
    if not test -L "$library/current"; or not test -L "$library/previous"
        echo "没有可回滚的 lemon fish 版本" >&2
        return 1
    end

    set -l current_target (command readlink -- "$library/current")
    set -l previous_target (command readlink -- "$library/previous")
    if not test -d "$library/$previous_target"
        echo "回滚目标不存在: $library/$previous_target" >&2
        return 1
    end

    __lemon_fish_update_switch_link "$library/current" "$previous_target"
    or return $status
    __lemon_fish_update_switch_link "$library/previous" "$current_target"
    or return $status

    echo "已回滚到: "(command basename -- "$previous_target")
    "$prefix/bin/fish" --version
end

function __lemon_fish_update_login_shell
    set -l user (command id -un)
    if type --query getent
        set -l account (command getent passwd "$user")
        set -l fields (string split : -- "$account")
        if test (count $fields) -ge 7
            echo $fields[7]
            return
        end
    end
    echo $SHELL
end

function __lemon_fish_update_status
    set -l prefix (__lemon_fish_update_setting LEMON_FISH_PREFIX /usr/local)
    set -l library "$prefix/lib/lemon-fish"
    set -l fish_path "$prefix/bin/fish"
    set -l current_tag (__lemon_fish_update_current_tag)
    set -l previous_tag
    if test -L "$library/previous"
        set previous_tag (command basename -- (command readlink -- "$library/previous"))
    end

    echo "安装根: $prefix"
    if test -n "$current_tag"
        echo "当前 tag: $current_tag"
    else
        echo "当前 tag: 未安装"
    end
    if test -n "$previous_tag"
        echo "上一 tag: $previous_tag"
    else
        echo "上一 tag: 无"
    end
    if test -x "$fish_path"
        echo "命令路径: $fish_path"
        echo "安装版本: "(string trim < "$library/current/version")
    else
        echo "命令路径: 尚未创建"
    end
    echo "登录 shell: "(__lemon_fish_update_login_shell)
    echo "当前进程: "(status fish-path)
end

function __lemon_fish_update_append_shell --argument-names fish_path shells_file
    if test (command id -u) -eq 0; or set -q LEMON_FISH_NO_SUDO
        printf '%s\n' "$fish_path" | command tee -a -- "$shells_file" >/dev/null
        return $pipestatus[2]
    end
    printf '%s\n' "$fish_path" | command sudo tee -a -- "$shells_file" >/dev/null
    return $pipestatus[2]
end

function __lemon_fish_update_activate
    set -l prefix (__lemon_fish_update_setting LEMON_FISH_PREFIX /usr/local)
    set -l shells_file (__lemon_fish_update_setting LEMON_FISH_SHELLS_FILE /etc/shells)
    set -l fish_path "$prefix/bin/fish"
    if not test -x "$fish_path"
        echo "尚未安装 lemon fish，请先运行: fish_update upgrade" >&2
        return 1
    end

    if not command grep -Fxq -- "$fish_path" "$shells_file" 2>/dev/null
        __lemon_fish_update_append_shell "$fish_path" "$shells_file"
        or return $status
        echo "已加入 $shells_file: $fish_path"
    end

    set -l login_shell (__lemon_fish_update_login_shell)
    if test "$login_shell" = "$fish_path"
        echo "登录 shell 已是: $fish_path"
        return
    end

    set -l user (command id -un)
    __lemon_fish_update_as_root chsh -s "$fish_path" "$user"
    or return $status
    echo "登录 shell 已切换为: $fish_path"
    echo "请注销并重新登录后验证: fish_update status"
end

function __lemon_fish_update_help
    printf '%s\n' \
        '用法: fish_update <命令>' \
        '' \
        '  check      查询远端最新 tag（默认）' \
        '  upgrade    构建并安装远端最新 tag' \
        '  status     查看安装、登录 shell 和当前进程' \
        '  activate   首次启用 /usr/local/bin/fish 作为登录 shell' \
        '  rollback   切回上一个已安装版本' \
        '  help       显示帮助'
end

function fish_update --description 'Check and install tagged builds from lemon956/fish-shell'
    set -l subcommand check
    if test (count $argv) -gt 0
        set subcommand $argv[1]
    end

    switch $subcommand
        case check
            set -l latest (__lemon_fish_update_latest)
            or return $status
            set -l fields (string split \t -- "$latest")
            set -l latest_tag $fields[1]
            set -l latest_commit $fields[2]
            set -l current_tag (__lemon_fish_update_current_tag)

            if test -z "$current_tag"
                echo "已安装: 未安装 lemon fish"
            else
                echo "已安装: $current_tag"
            end
            echo "远端最新: $latest_tag"
            echo "提交: $latest_commit"

            if test "$current_tag" = "$latest_tag"
                echo "状态: 已是最新"
            else
                echo "状态: 有可用更新"
            end
        case upgrade
            __lemon_fish_update_upgrade
        case rollback
            __lemon_fish_update_rollback
        case status
            __lemon_fish_update_status
        case activate
            __lemon_fish_update_activate
        case help -h --help
            __lemon_fish_update_help
        case '*'
            echo "未知子命令: $subcommand" >&2
            __lemon_fish_update_help >&2
            return 2
    end
end
