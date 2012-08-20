setup:
	@git submodule init
	@git submodule update
	@./bin/dotfiles_setup.sh

.PHONY: setup
