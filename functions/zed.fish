function zed --description 'Open VS Code workspace files in Zed'
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

    command zed $argv
end
