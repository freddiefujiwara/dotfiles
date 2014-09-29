#!/bin/sh

#for vim
rm -rf ~/.vim
rm -f ~/.vimrc
ln -s ~/.dotfiles/vimrc/_vimrc ~/.vimrc
mkdir -p  ~/.dotfiles/.vim
ln -s ~/.dotfiles/.vim ~/
#for screen
rm -f  ~/.screenrc
ln -s ~/.dotfiles/_screenrc ~/.screenrc
