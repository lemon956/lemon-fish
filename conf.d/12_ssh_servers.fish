# SSH server shortcuts
alias gcyus='ssh root@173.249.220.74'
alias bwgus='ssh root@104.225.235.250'
alias txhk='ssh lemon@43.134.131.211'

# Local SOCKS5 proxies (run in foreground; press Ctrl+C to stop)
alias gcyus-proxy='ssh -N -T -D 127.0.0.1:1081 -o ExitOnForwardFailure=yes root@173.249.220.74'
alias bwgus-proxy='ssh -N -T -D 127.0.0.1:1082 -o ExitOnForwardFailure=yes root@104.225.235.250'
alias txhk-proxy='ssh -N -T -D 127.0.0.1:1083 -o ExitOnForwardFailure=yes lemon@43.134.131.211'
