# Go 语言环境配置
if test -d $HOME/.go-switch/gos/go1.24.6
    set -gx GOROOT $HOME/.go-switch/gos/go1.24.6
    set -gx GOPATH $HOME/go
    
    # 将 Go 路径添加到 PATH 前面
    if not contains $GOROOT/bin $PATH
        set -gx PATH $GOROOT/bin $PATH
    end
    
    if not contains $GOPATH/bin $PATH
        set -gx PATH $GOPATH/bin $PATH
    end
end

