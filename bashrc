HISTSIZE=1000
HISTFILESIZE=2000

eval `dircolors ~/.dircolors`
export GREP_OPTIONS='--color=auto'
alias ls='ls --color'
export PS1="$(tput setaf 1)\w\n\[$(tput bold)\]\[$(tput setaf 1)\][\[$(tput setaf 3)\]\u\[$(tput setaf 2)\]@\[$(tput setaf 4)\]\h\[$(tput setaf 5)\]\[$(tput setaf 1)\]]\[$(tput setaf 7)\]\\$\[$(tput sgr0)\] "