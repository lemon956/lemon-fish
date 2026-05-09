# Fish Shell 主配置文件
# 具体配置请放在 conf.d/ 目录下
if status is-interactive
# 交互式会话的命令可以放在这里
# 交互式会话的命令可以放在这里
end
# fzf 配置
if test -f ~/.fzf/shell/key-bindings.fish
source ~/.fzf/shell/key-bindings.fish
fzf_key_bindings
source ~/.fzf/shell/key-bindings.fish
fzf_key_bindings
end
# 配置opengl 问题，可以修复无法播放视频的问题
set -gx GDK_GL gles
# go-switch
if test -f /home/lemon/.go-switch/environment/system.fish; source /home/lemon/.go-switch/environment/system.fish; end
# cargo
if test -f "$HOME/.cargo/env.fish"
source "$HOME/.cargo/env.fish"
end
# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
# linuxbrew
if test -d /home/linuxbrew/.linuxbrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
else if test -d ~/.linuxbrew
eval "$(~/.linuxbrew/bin/brew shellenv)"
end
# opencode
fish_add_path /home/lemon/.opencode/bin
fish_add_path ~/.npm-global/bin
