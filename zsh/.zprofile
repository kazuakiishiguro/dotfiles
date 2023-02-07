# for brew
eval "$(/opt/homebrew/bin/brew shellenv)"

# always load .zshrc
if [ -f ~/.zshrc ]; then
    . ~/.zshrc
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
