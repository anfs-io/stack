# hammerspoon
# https://www.hammerspoon.org/go/#helloworld

pre_install() { return; }
install_linux() { return; }

install_macos() {
  # brew install hammerspoon
  spoons=("AClock" "BingDaily")
  spoon_dir=$HOME/.hammerspoon/Spoons
  mkdir -p $spoon_dir
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

post_install() { return; }
