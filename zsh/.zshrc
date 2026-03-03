# --- Shared config ---
source ~/.shellrc

# --- Platform-specific ---
if [[ `uname -a` == *Ubuntu* ]]; then
  if command -v Xorg >/dev/null 2>&1; then
    source $HOME/.bin/start-xcape.sh
  fi
fi

# --- Prompt ---
autoload -Uz vcs_info
setopt prompt_subst

zstyle ':vcs_info:*' formats "%F{green}%c%u(%b)%f"
precmd () { vcs_info }

PROMPT='%n@%m:%F{cyan}%~%f%F{green}$vcs_info_msg_0_%f$ '

# --- fzf ---
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
