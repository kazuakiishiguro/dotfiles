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



if '__main__' == __name__:
    version = platform.python_version_tuple()
    if version[0] == '2':
        print('Only work with python3.')
        sys.exit(1)
    vim()