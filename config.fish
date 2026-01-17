# Fish Shell 主配置文件
# 具体配置请放在 conf.d/ 目录下
if status is-interactive
# 交互式会话的命令可以放在这里
end
# fzf 配置
if test -f ~/.fzf/shell/key-bindings.fish
source ~/.fzf/shell/key-bindings.fish
fzf_key_bindings
end
# 配置opengl 问题，可以修复无法播放视频的问题
set -gx GDK_GL gles
if test -f /home/lemon/.go-switch/environment/system.fish; source /home/lemon/.go-switch/environment/system.fish; end

if status is-interactive
    and not set -q TMUX
    and command -q tmux

    set last (tmux list-sessions -F "#{session_last_attached} #{session_name}" 2>/dev/null \
        | sort -rn | head -n1 | awk '{print $2}')

    if test -n "$last"
        exec tmux attach -t $last
    else
        exec tmux new -s main
    end
end
