complete -c fish_update -f
complete -c fish_update -n 'not __fish_seen_subcommand_from check upgrade status activate rollback help' \
    -a check -d '查询远端最新 tag'
complete -c fish_update -n 'not __fish_seen_subcommand_from check upgrade status activate rollback help' \
    -a upgrade -d '构建并安装最新 tag'
complete -c fish_update -n 'not __fish_seen_subcommand_from check upgrade status activate rollback help' \
    -a status -d '显示当前安装状态'
complete -c fish_update -n 'not __fish_seen_subcommand_from check upgrade status activate rollback help' \
    -a activate -d '设为登录 shell'
complete -c fish_update -n 'not __fish_seen_subcommand_from check upgrade status activate rollback help' \
    -a rollback -d '切回上一个版本'
complete -c fish_update -n 'not __fish_seen_subcommand_from check upgrade status activate rollback help' \
    -a help -d '显示帮助'
