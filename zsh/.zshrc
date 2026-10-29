# --- Shared config ---
source ~/.shellrc

# Prompt, completion and desktop helpers are only for interactive shells.
[[ $- != *i* ]] && return 0

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
# GUI Emacs queries a non-TTY interactive login shell for PATH. Its ZLE is
# unavailable, so install keybindings only in an actual interactive terminal.
if [[ -o zle && -t 0 ]] && command -v fzf >/dev/null 2>&1; then
  if _dotfiles_fzf_init=$(fzf --zsh 2>/dev/null); then
    eval "$_dotfiles_fzf_init"
  elif [ -f "$HOME/.fzf.zsh" ]; then
    source "$HOME/.fzf.zsh"
  fi
  unset _dotfiles_fzf_init
fi
