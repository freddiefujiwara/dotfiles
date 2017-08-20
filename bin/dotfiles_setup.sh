#!/bin/sh

#for vim
rm -rf ~/.vim
rm -f ~/.vimrc
ln -s ~/.dotfiles/vimrc/_vimrc ~/.vimrc
mkdir -p  ~/.dotfiles/.vim
ln -s ~/.dotfiles/.vim ~/
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
#for screen
rm -f  ~/.screenrc
ln -s ~/.dotfiles/_screenrc ~/.screenrc
