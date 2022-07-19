scriptencoding utf-8
set encoding=utf-8

set runtimepath^=$VIM_PATH

" command mode :
" :echo $MYVIMRC   show where your vimrc is.

" 键值映射
nnoremap  <c-]>  g<c-]>      " 键值映射  ctrl+]  映射为  g+ctrl+]
" should check dependenccy, libjansson-dev and libxml2 for new ctags
nnoremap <F2> :Tagbar<CR><esc><c-w>=  " Tlist trigger and make all windows equally high and wide
" nnoremap <F2> :Tlist<CR><esc><c-w>=  " Tlist trigger and make all windows equally high and wide
nnoremap <F4> :close<CR>     " 多个窗口时，快速关闭当前窗口
" cnoremap mse :Sexplore<CR>   " 横屏分割，打开netrw Explore
" cnoremap mve :Vexplore<CR>   " 竖屏分割，打开netrw Explore

" key map binding for NERDTree plugin
map <F10> :NERDTreeToggle<CR>

map <F7> :set paste<CR>
map <F8> :set nopaste<CR>
imap <F7> <C-O>:set paste<CR>
imap <F8> <nop>
set pastetoggle=<F8>

" turn off compatible mode
" set nocompatible will sets many options, so set it first
" to avoid it affects other options.
set nocompatible
set fileformat=unix
set fileformats=unix
set cc=80                " vim7.3默认提供了colorcolumn，即在第80列显示红色宽度线, cuc 表示将当前光标下的列高亮
set updatetime=1000      " 设定更新.swp 文件时间，milliseconds，此值影响taglist插件更新快慢
set shiftwidth=4         " 设定 << 和 >> 命令移动时的宽度为 4, code auto indent width
set softtabstop=4        " 使得按退格键时可以一次删掉 4 个空格
set tabstop=8            " 设定 tab 长度为 4
set number               " 显示行号
set showmatch            " 插入括号时，短暂地跳转到匹配的对应括号
set matchtime=2          " 短暂跳转到匹配括号的时间

set hlsearch              " 搜索时高亮显示被找到的文本
set ignorecase            " 搜索忽略大小写  关闭  set  noignorecase
set ignorecase smartcase  " 搜索时忽略大小写，但在有一个或以上大写字母时仍保持对大小写敏感
set wrapscan              " 搜索到文件两端时重新搜索
set incsearch             " 输入搜索内容时就显示搜索结果
set cursorline            " 当前的整行显示下划线
set scrolloff=5           " 距离屏幕最上或最下5行时scrollbar开始滚动
set list                  " 显示不可视字符 , 如tab符号，行结尾符号 ， nolist 不显示
set wildmenu              " vim 自身命令行模式智能补全
set autoindent
set smartindent
set cindent                      " c 语言语法缩进，good
" C/C++ indent options, help cinoptions-values
set cinoptions=(0,W8,U0,:0,g0,l1,t0,N-4,E-4

if v:version > 704
  set listchars=trail:¶  " [ 二合字母：crtl+k  PI ]  显示行尾的空格，:help dig
else
  set listchars=trail:~
endif

set listchars+=tab:>-  " [二合字母：crtl+k  14]    +: append listchars setting， tab will be showed as >----

set laststatus=2       " 显示状态栏 (默认值为 1, 无法显示状态栏), 设为1则窗口数多于一个的时候
                       " 显示最后一个窗口的状态行；0不显示最后一个窗口的状态行
set ruler
set showmode         " 显示insert visual等模式提示

set cmdheight=1               " 设定命令行的行数为 1

set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
set termencoding=utf-8
set encoding=utf-8    " 上面三行，多语言编码支持
" set autochdir " auto change directory

" set nowrap                     " 禁止折行
" set backspace=indent,eol,start   " 不设定在插入状态无法用退格键和 Delete 键删除回车符
" set backup                        "开启备份，内建设定备份文件的名字是 源文件名加一个 ‘~’ (enable backup default filename+~)
" set backupcopy=yes         " 设置备份时的行为为覆盖
" set backupext=.bak           "设定备份文件名为源文件名.bak (change backup as filename.bak)
" 自动备份有个问题就是，如果多次储存一个文件，那么备份文件会被不断覆盖，只有最后一次存文件之前的那个备份。
" vim还提 供了patchmode，这个会把第一次的原始文件备份下来，不会改动
" set patchmode=.orig         "保存原始文件为 文件名.orig (keep orignal file as filename.orig)

syntax on            " 自动语法高亮，会覆盖已有的颜色
syntax enable        " 打开语法的颜色显示 (turn on syntax color) , 只会设置没有设置过的组

filetype on          " 开启文件类型侦测
filetype plugin on   " 根据侦测到的不同类型加载对应的插件
filetype plugin indent on
" 将指定文件类型，空格自动转换为tab，手动使用以下命令
" :set expandtab
" :retab     ** command mode
autocmd FileType h,c,cpp,cxx,cc,java setlocal expandtab
autocmd BufNewFile,BufRead *.sh set expandtab tabstop=8 softtabstop=4 shiftwidth=4
autocmd BufNewFile,BufRead *.py let g:indentLine_enabled=1 " for indentLine

" filetype plugin on, then turns on omni completion
set omnifunc=ClangComplete
set completefunc=ClangComplete

function! WindowNumber()
    let num=tabpagewinnr(tabpagenr())
        return num
endfunction
set statusline=%<%F%M%r\ [%{&fileformat}][%{&fileencoding?&fileencoding:&encoding}]%=\ %l:%c\ %p%%\ win:%{WindowNumber()}

colorscheme peachpuffx       " 配色方案在/usr/share/vim/vim73/colors下

" set netrw maxium number of modified directories to 0
let g:netrw_dirhistmax = 0
" set current history count of modified directories to 0
let g:netrw_dirhist_cnt = 0

let g:tagbar_left = 1
let g:tagbar_foldlevel = 1
let g:tagbar_sort = 0
let g:tagbar_width = 30

if has("cscope")
    set csprg=/usr/bin/cscope
    set csto=1
    set cst
    " set csverb  " output verbose message and wait enter key
    set cspc=10
    set nocscopeverbose
    if filereadable("cscope.out")    "add any database in current dir
        cs add cscope.out . -C
    else    "else search cscope.out elsewhere
        let cscope_file=findfile("cscope.out", ".;")
        let cscope_pre=matchstr(cscope_file, ".*/")
        if !empty(cscope_file) && filereadable(cscope_file)        "echo cscope_file
            exe "cs add" cscope_file cscope_pre "-C"
        endif
    endif
endif

if filereadable("tags") "add any database in current dir
    set tags=tags
else "else search tags elsewhere
    let tags_file=findfile("tags", ".;")
    if !empty(tags_file) && filereadable(tags_file)
        exe "set tags=" . tags_file
    endif
endif

" 设置字体 以及中文支持
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
if has("win32")
    set guifont=Inconsolata:h12:cANSI
endif

let Tlist_Exit_OnlyWindow=1       " exit taglist when only left taglist window
let Tlist_Show_One_File=1         " only display tags for current active buffer

" llvm lib config example: path to directory where library can be found
let g:clang_library_path='/usr/lib/llvm-7/lib/libclang.so.1'
let g:clang_jumpto_declaration_key='<C-B>'
let g:clang_jumpto_declaration_in_preview_key='<C-M>'
let g:clang_jumpto_back_key='<C-N>'

" plugins installed by vim-plug
" PlugInstall command
call plug#begin()
Plug 'aklt/plantuml-syntax'
Plug 'preservim/nerdcommenter'
Plug 'majutsushi/tagbar'
Plug 'hail2u/vim-css3-syntax', { 'for': 'css' } " CSS syntax support
Plug 'groenewege/vim-less', { 'for': 'css' } " LESS support
Plug 'pangloss/vim-javascript', { 'for': 'javascript' } " JavaScript syntax support
Plug 'nathanaelkane/vim-indent-guides', { 'for': [ 'c', 'cpp', 'java', 'css', 'javascript' ] } " visually displaying indent levels
Plug 'Yggdroot/indentLine', { 'for': 'python' }
Plug 'scrooloose/nerdtree'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'will133/vim-dirdiff'
Plug 'xavierd/clang_complete'
Plug 'udalov/kotlin-vim'
call plug#end()
