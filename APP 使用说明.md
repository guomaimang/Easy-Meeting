# 1. 拖入 /Applications（或在 Finder 里拖）
mv ~/Downloads/"Easy Meeting.app" /Applications/

# 2. 一次性去隔离（Ad-hoc 签名未公证，必须做这步，否则 Gatekeeper 会拦）
xattr -dr com.apple.quarantine "/Applications/Easy Meeting.app"

# 3. 启动
open "/Applications/Easy Meeting.app"