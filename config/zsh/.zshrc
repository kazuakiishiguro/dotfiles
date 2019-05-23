export DOTFILES=$HOME/.dotfiles
export ZSH=$DOTFILES/config/zsh
export PATH=/usr/local/bin:$PATH

if [[ -d /usr/local/sbin ]]; then
  export PATH=/usr/local/sbin:$PATH
fi

# adding path directory for custom scrips
export PATH=$DOTFILES/bin:$PATH

# check for custom bin directory and add to path
if [[ -d ~/bin ]]; then
  export PATH=~/bin:$PATH
fi

# compinstall
autoload -U compinit add-zsh-hook
compinit

# source all .zsh files inside of the zsh/ directory
for config ($ZSH/**/*.zsh) source $config

# environment settings
source $ZSH/.zshrc.env

# fzf setting
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# added by travis gem
[ -f /Users/kazuaki/.travis/travis.sh ] && source /Users/kazuaki/.travis/travis.sh