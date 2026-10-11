# omlx

install_macos() {
  brew tap jundot/omlx https://github.com/jundot/omlx
  brew trust jundot/omlx
  # install_dep omlx
  brew install omlx --with-grammar
}

# install huggingface CLI
# brew install hf
 # Download your Gemma model into oMLX using the Homebrew version
# hf download lmstudio-community/gemma-4-26B-A4B-it-QAT-MLX-4bit \
#  --local-dir ~/.omlx/models/gemma-4-26B-A4B-it-QAT-MLX-4bit

