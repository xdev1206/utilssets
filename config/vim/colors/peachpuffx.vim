" Vim color file
" Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2003-04-23
" URL: http://trific.ath.cx/Ftp/vim/colors/peachpuff.vim

" This color scheme uses a peachpuff background (what you've expected when it's
" called peachpuff?).

" color palette
" 0 black
" 1 red
" 2 green
" 3 yellow
" 4 blue
" 5 magenta
" 6 cyan
" 7 white

" Note: Only GUI colors differ from default, on terminal it's just `light'.

" First remove all existing highlighting.
set background=dark
hi clear
if version > 580
    " no guarantees for version 5.8 and below, but this makes it stop
    " complaining
    if exists("syntax_on")
        syntax reset
    endif
endif

let colors_name = "peachpuffx"
if has("gui_running") || &t_Co == 256
    " Colors for syntax highlighting
    hi Comment cterm=NONE ctermfg=Gray ctermbg=Black gui=NONE guifg=#585858 guibg=#000000
else
    " Colors for syntax highlighting
    hi Comment cterm=NONE ctermfg=Gray ctermbg=Black
endif

hi Normal guibg=PeachPuff guifg=Black
hi SpecialKey term=bold ctermfg=4 guifg=Blue
hi NonText term=bold cterm=bold ctermfg=4 gui=bold guifg=Blue
hi Directory term=bold ctermfg=4 guifg=Blue
hi ErrorMsg term=standout cterm=bold ctermfg=7 ctermbg=1 gui=bold guifg=White guibg=Red
hi IncSearch term=reverse cterm=reverse gui=reverse
hi Search term=reverse ctermfg=4 ctermbg=3 guibg=Gold2
hi MoreMsg term=bold ctermfg=2 gui=bold guifg=SeaGreen
hi ModeMsg term=bold cterm=bold gui=bold
hi LineNr term=underline ctermfg=3 guifg=Red3
hi Question term=standout ctermfg=2 gui=bold guifg=SeaGreen
hi StatusLine term=bold,reverse cterm=bold,reverse ctermfg=7 ctermbg=0 gui=bold guifg=White guibg=Black
hi StatusLineNC term=reverse cterm=reverse ctermfg=3 ctermbg=4 gui=bold guifg=PeachPuff guibg=Gray45
hi VertSplit term=reverse cterm=reverse gui=bold guifg=White guibg=Gray45
hi Title term=bold ctermfg=5 gui=bold guifg=DeepPink3
hi Visual term=reverse cterm=reverse ctermfg=7 ctermbg=0 gui=reverse guifg=Grey80 guibg=fg
hi VisualNOS term=bold,underline cterm=bold,underline gui=bold,underline
hi WarningMsg term=standout ctermfg=1 gui=bold guifg=Red
hi WildMenu term=standout ctermfg=0 ctermbg=3 guifg=Black guibg=Yellow
hi Folded term=standout ctermfg=4 ctermbg=7 guifg=Black guibg=#e3c1a5
hi FoldColumn term=standout ctermfg=4 ctermbg=7 guifg=DarkBlue guibg=Gray80
hi DiffAdd term=bold ctermbg=4 guibg=White
hi DiffChange term=bold ctermbg=5 guibg=#edb5cd
hi DiffDelete term=bold cterm=bold ctermfg=4 ctermbg=6 gui=bold guifg=LightBlue guibg=#f6e8d0
hi DiffText term=reverse cterm=bold ctermbg=1 gui=bold guibg=#ff8060
hi Cursor guifg=bg guibg=fg
hi lCursor guifg=bg guibg=fg
hi Constant term=underline ctermfg=1 guifg=#c00058
hi Special term=bold ctermfg=5 guifg=SlateBlue
hi Identifier term=underline ctermfg=6 guifg=DarkCyan
hi Statement term=bold ctermfg=3 gui=bold guifg=Brown
hi PreProc term=underline ctermfg=5 guifg=Magenta3
hi Type term=underline ctermfg=2 gui=bold guifg=SeaGreen
hi Ignore cterm=bold ctermfg=7 guifg=bg
hi Error term=reverse cterm=bold ctermfg=7 ctermbg=1 gui=bold guifg=White guibg=Red
hi Todo term=standout ctermfg=0 ctermbg=3 guifg=Blue guibg=Yellow
hi ColorColumn ctermfg=1 ctermbg=6 guibg=DarkGrey
" vimdiff
highlight DiffAdd    cterm=bold ctermfg=7 ctermbg=1 gui=none guifg=bg guibg=Red
highlight DiffDelete cterm=bold ctermfg=1 ctermbg=3 gui=none guifg=bg guibg=Red
highlight DiffChange cterm=bold ctermfg=0 ctermbg=5 gui=none guifg=bg guibg=Red
highlight DiffText   cterm=bold ctermfg=7 ctermbg=6 gui=none guifg=bg guibg=Red
