HISTSIZE=1000
HISTFILESIZE=2000

# ~/.dircolors/themefile
eval $(gdircolors ~/.dircolors/dircolors.256dark)

# aliases
alias ls='gls --color=auto'
alias ll='ls -al'

# rustc path setting
export PATH=${HOME}/.cargo/bin:${PATH}
