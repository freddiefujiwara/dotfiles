set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
call plug#begin('~/.vim/plugged')

Plug 'nvim-lua/plenary.nvim'
Plug 'MunifTanjim/nui.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'stevearc/dressing.nvim'

Plug 'yetone/avante.nvim', { 'branch': 'main', 'do': 'make' }

call plug#end()
lua << EOF
require('avante').setup({
  provider = "gemini",
  providers = {
    openai = {
      endpoint = "https://api.openai.com/v1",
      model = "gpt-4o",
      timeout = 30000,
      extra_request_body = {
        temperature = 0,
        max_tokens = 4096,
      },
    },
    gemini = {
      endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
      model = "gemini-flash-latest",
      timeout = 30000,
      temperature = 0,
      max_tokens = 4096,
    },
  },
})
EOF
