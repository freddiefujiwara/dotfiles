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
  provider = "openai",
  -- 'openai = { ... }' ではなく 'providers = { openai = { ... } }' に変更
  providers = {
    openai = {
      endpoint = "https://api.openai.com/v1",
      model = "gpt-4o",
      timeout = 30000,
      -- temperatureなどは extra_request_body の中へ移動
      extra_request_body = {
        temperature = 0,
        max_tokens = 4096,
      },
    },
  },
})
EOF
