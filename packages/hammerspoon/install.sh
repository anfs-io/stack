# hammerspoon
# https://www.hammerspoon.org/go/#helloworld

install_macos() {
  install_dep hammerspoon

  spoon_dir=$HOME/.hammerspoon/Spoons
  mkdir -p $spoon_dir

  spoons=("AClock" "BingDaily")
  for spoon in "${spoons[@]}"; do
    if [[ ! -d "$spoon_dir/$spoon.spoon" ]]; then
      echo "Installing spoon: $spoon"
      curl -L https://github.com/Hammerspoon/Spoons/raw/master/Spoons/$spoon.spoon.zip -o /tmp/$spoon.spoon.zip
      unzip -q /tmp/$spoon.spoon.zip -d $spoon_dir
      rm /tmp/$spoon.spoon.zip
    else
      echo "Spoon already installed: $spoon"
    fi
  done
}
