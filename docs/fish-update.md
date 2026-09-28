# Fish fork 自动打 tag 与本地更新

这套流程不制作 RPM，也不替换 Fedora 的 `/usr/bin/fish`：

1. `lemon956/fish-shell` 自己的 `sync-upstream.yml` 每天北京时间 11:17 自动合并上游 `master` 到 `lemon`。
2. 合并结果在 `fish-shell` 仓库内通过 `cargo xtask check` 后，workflow 原子推送 `lemon` 分支和轻量 tag。
3. 本仓库只提供本机 `fish_update`，用于检查、构建并切换到这个 tag。

tag 格式为 `lemon-YYYYMMDDTHHMMSSZ-g<12位提交>`。它是轻量 tag，不会改变 fish 自己的 `git describe` 版本号。

## Fish fork 自动更新与打 tag

自动化 workflow 位于 `lemon956/fish-shell` 自身，因此直接使用该仓库的 `GITHUB_TOKEN`，不需要 personal access token，也不需要在 `lemon-fish` 配置 secret。

将 `.github/workflows/sync-upstream.yml` 推送到 `fish-shell` 的 `lemon` 分支后，在 Actions 中手动运行一次 `Sync upstream into lemon`。后续由定时任务完成：

```text
合并 upstream/master → cargo xtask check → 原子推送 lemon + lemon-* tag
```

同一 fish 提交已有 `lemon-*` tag 时不会重复打 tag；即使没有新的上游提交，只要当前提交尚未打 tag，workflow 也会先验证再补 tag。

## 本机首次启用

先确认 Rust、Git 和 gettext 已安装。Fedora 可以运行：

```console
sudo dnf install git cargo gettext
```

然后执行：

```console
fish_update check
fish_update upgrade
fish_update activate
```

`upgrade` 将源码 clone 到临时目录，执行 locked release build，并安装三个独立二进制：

- `/usr/local/bin/fish`
- `/usr/local/bin/fish_indent`
- `/usr/local/bin/fish_key_reader`

实际版本保存在 `/usr/local/lib/lemon-fish/releases/<tag>/`，`current` 与 `previous` 链接负责切换和回滚。`activate` 会将 `/usr/local/bin/fish` 加入 `/etc/shells`，然后把它设为当前账户的登录 shell。注销并重新登录后执行：

```console
fish_update status
```

## 日常更新与回滚

```console
# 只检查，不修改本机
fish_update check

# 有更新时构建并切换
fish_update upgrade

# 查看 current、previous、登录 shell 和当前进程
fish_update status

# 出现问题时切回上一个已安装版本
fish_update rollback
```

升级不会修改 `/home/lemon/lemon/github/fish-shell` 的分支、工作区或未提交文件。

Fedora 的官方 fish RPM 仍保留在 `/usr/bin/fish`，因此 `dnf upgrade fish` 只会更新官方副本，不会更新 `/usr/local/bin/fish`。自定义版本统一通过 `fish_update` 更新；如需紧急恢复官方版本，可运行 `sudo chsh -s /bin/fish lemon` 后注销并重新登录。
