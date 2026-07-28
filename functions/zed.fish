function zed --description 'Open directories and VS Code workspace files in new Zed windows'
    if test (count $argv) -eq 1
        and string match --quiet '*.code-workspace' -- "$argv[1]"

        if not test -f "$argv[1]"
            echo "Workspace 不存在: $argv[1]" >&2
            return 1
        end

        set -l workspace (realpath -- "$argv[1]")
        set -l workspace_dir (dirname -- "$workspace")
        set -l roots

        set -l folder_paths (jq -r '.folders[]? | .path // empty' "$workspace")
        or begin
            echo "无法解析 workspace: $workspace" >&2
            return 1
        end

        for folder in $folder_paths
            if string match --quiet '~*' -- "$folder"
                set folder (string replace --regex '^~' "$HOME" -- "$folder")
            end

            if string match --quiet --regex '^/' -- "$folder"
                set --append roots (realpath -m -- "$folder")
            else
                set --append roots (realpath -m -- "$workspace_dir/$folder")
            end
        end

        if test (count $roots) -eq 0
            echo "Workspace 中没有有效的 folders[].path" >&2
            return 1
        end

        command zed -n $roots
        return $status
    end

    set -l has_directory false
    set -l has_window_behavior false
    set -l option_values_to_skip 0
    set -l parsing_options true

    for arg in $argv
        if test $option_values_to_skip -gt 0
            set option_values_to_skip (math $option_values_to_skip - 1)
            continue
        end

        if test "$parsing_options" = true
            switch $arg
                case '--'
                    set parsing_options false
                case '-n' '--new' '-e' '--existing' '-a' '--add'
                    set has_window_behavior true
                case '--user-data-dir' '--zed' '--dev-server-token' '--completions'
                    set option_values_to_skip 1
                case '--diff'
                    set option_values_to_skip 2
                case '-*'
                    continue
                case '*'
                    if test -d "$arg"
                        set has_directory true
                    end
            end
        else
            if test -d "$arg"
                set has_directory true
            end
        end
    end

    if test "$has_directory" = true
        and test "$has_window_behavior" = false
        command zed -n $argv
        return $status
    end

    command zed $argv
end
