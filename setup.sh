#!/bin/sh

#for vim
rm -rf ~/.vim
rm -f ~/.vimrc
ln -s ~/.dotfiles/vimrc/_vimrc ~/.vimrc
ln -s ~/.dotfiles/.vim ~/
#for screen
rm -f  ~/.screenrc
ln -s ~/.dotfiles/_screenrc ~/.screenrc
