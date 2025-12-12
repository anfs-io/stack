# linux

if [ $(ostype) != "linux" ]; then
  return
fi

# alias ip_addr="echo $(hostname -I | awk '{print $1}')"
alias ip_addr="echo $(ip route get 8.8.8.8 | awk '{print $7}' | head -1)"
alias bat=batcat
