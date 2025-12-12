# macos

if [ $(ostype) != "macos" ]; then
  return
fi

alias ip_addr="echo $(route get 8.8.8.8 | grep interface | awk '{print $2}' | xargs ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"

# Is this redundant to loading homebrew zsh functions at top of aliases.zsh?
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
