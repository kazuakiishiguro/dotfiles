# -- Export Setting -----------------------------------------------------------
export LANG=ja_JP.UTF-8
export PROMPT="> %F{green}$%f "
export PROMPT2="> "
export HISTFILE="~/.zsh_history"
export HISTSIZE="10000"
export SAVEHIST="10000"
export KEYTIMEOUT=1

# -- Auto complete ------------------------------------------------------------
autoload -Uz compinit
compinit

setopt NO_BG_NICE
setopt NO_HUP
setopt NO_LIST_BEEP
setopt LOCAL_OPTIONS
setopt LOCAL_TRAPS
setopt PROMPT_SUBST

# -- History ------------------------------------------------------------------
setopt HIST_VERIFY
setopt EXTENDED_HISTORY
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY
setopt APPEND_HISTORY

setopt COMPLETE_ALIASES

fpath=($ZSH/functions $fpath)
autoload -U $ZSH/functions/*(:t)