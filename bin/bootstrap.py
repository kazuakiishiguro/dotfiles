#!/usr/bin/env python

import os
import sys
import platform

linux = platform.linux_distribution()[0]

# ---------------------------------------------------------------
# neovim

def vim():
    print('>>> neovim & vim')
    if not os.path.exists(os.environ['HOME'] + '/.vim'):
        os.mkdir(os.environ['HOME'] + '/.vim')
    # neovim
    os.system('ln -nsf ~/.dotfiles/config/nvim ~/.config')
    # vim
    os.system('ln -sf ~/.dotfiles/config/nvim/init.vim ~/.vimrc')
    print('<<< [ok] neovim & vim')

# ---------------------------------------------------------------
# tmux

def tmux():
    print('>>> tmux')
    # check if tmux-powerline directory exists
    if os.path.isdir(os.environ['HOME'] + '/.tmux-powerline/') == False:
        os.system('git clone https://github.com/erikw/tmux-powerline.git ~/.tmux-powerline')

    if os.path.isdir(os.environ['HOME'] + '/.tmux_mem_cpu_load') == False:
        os.system('git clone https://github.com/thewtex/tmux-mem-cpu-load.git ~/.tmux-mem-cpu-load')
        os.system('source ~/.dotfiles/install/tmux-mem-cpu-load.sh')

    global os_name
    
    if linux:
        if linux == 'Ubuntu':
            os_name = 'ubuntu'
            os.system('ln -sf ~/.dotfiles/config/tmux/weather.sh ~/.tmux-powerline/segments/weather.sh')
        else:
            os_name = 'vm'
    else:
        # mac
        os_name = 'osx'
    os.system('ln -sf ~/.dotfiles/config/tmux/.tmux.conf ~/.tmux.conf')
    os.system('ln -sf ~/.dotfiles/config/tmux/default_{}.sh ~/.tmux-powerline/themes/default.sh'.format(os_name))
    os.system('ln -sf ~/.dotfiles/config/tmux/tmux_mem_cpu_load.sh ~/.tmux-powerline/segments/tmux_mem_cpu_load.sh')
    print('<<< [ok] tmux')

# ---------------------------------------------------------------
# git

def git():
    print('>>> git')
    os.system('ln -sf ~/.dotfiles/config/git/.gitconfig ~/.gitconfig')
    print('<<< [ok] git')

# ---------------------------------------------------------------
# zsh

def zsh():
    print('>>> zsh')
    os.system('ln -nsf ~/.dotfiles/config/zsh/.zshrc ~/.zshrc')
    print('<<< [ok] zsh')

def default():
    print('>>> default')
    os.system('~/.dotfiles/install/{}.sh'.format(os_name))
    os.system('~/.dotfiles/install/link.sh')
    os.system('~/.dotfiles/install/git.sh')
    print('<<< [ok] default')

if '__main__' == __name__:
    version = platform.python_version_tuple()
    if version[0] == '2':
        print('Only work with python3.')
        sys.exit(1)
    git()
    zsh()
    # vim()
    tmux()
    default()