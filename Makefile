all: setup

install:
	mkdir -p ~/.bin ~/.test ~/.newsboat ~/.config
	cp -a .bin/. ~/.bin/
	cp -a .test/. ~/.test/
	cp -a .newsboat/. ~/.newsboat/
	cp -a .config/. ~/.config/

setup: install
	rm -rf ~/.vim
	rm -f ~/.vimrc
	ln -s ~/.dotfiles/vimrc/_vimrc ~/.vimrc
	mkdir -p  ~/.dotfiles/.vim
	ln -s ~/.dotfiles/.vim ~/
	curl -fLo ~/.vim/autoload/plug.vim                   --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

test:
	bats .test/

.PHONY: install setup test
