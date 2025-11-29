# Starship 提示符初始化
if status --is-interactive
    if type -q starship
        source (starship init fish | psub)
    end
end

