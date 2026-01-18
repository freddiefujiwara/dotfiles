install:
	mkdir -p ~/.bin ~/.test
	cp -a .bin/. ~/.bin/
	cp -a .test/. ~/.test/

setup:
	rm -rf ~/.vim
	rm -f ~/.vimrc
	ln -s ~/.dotfiles/vimrc/_vimrc ~/.vimrc
	mkdir -p  ~/.dotfiles/.vim
	ln -s ~/.dotfiles/.vim ~/
	curl -fLo ~/.vim/autoload/plug.vim                   --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	rm -f  ~/.screenrc
	ln -s ~/.dotfiles/_screenrc ~/.screenrc

test:
	bats .test/

.PHONY: install setup test
