# for brew
eval "$(/opt/homebrew/bin/brew shellenv)"

# always load .zshrc
if [ -e "$HOME/.zshrc" ]; then
    . "$HOME/.zshrc"
fi

# load .zprofile.local
if [ -e "$HOME/.zprofile.local" ]; then
    . "$HOME/.zprofile.local"
fi

# lang
if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
  export LC_ALL="en_US.UTF-8"
fi

# cargo
if [ -e "$HOME/.cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
