syntax on
set tabstop=2 softtabstop=2 shiftwidth=2
set expandtab
set number ruler
filetype plugin indent on

call plug#begin()

" List your plugins here
Plug 'tpope/vim-sensible'
Plug 'preservim/vim-pencil'

call plug#end()

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

augroup pencil
  autocmd!
  autocmd FileType markdown,mkd call pencil#init()
  autocmd FileType text         call pencil#init()
augroup END
