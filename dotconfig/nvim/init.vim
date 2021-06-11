" filetype plugin indent on  " more complex indentation
set shiftwidth=4
set softtabstop=4
set expandtab     " tabs to spaces
set smarttab
set shiftround
set smartcase
set autoindent    " redundant in nvim
set incsearch     " highlight while searching
set cursorline    " highlights (e.g. underlines) current line of cursor
set number relativenumber " showing the current line number only in this line,
                          " and relative line numbers everywhere else.
set tabpagemax=100
set noswapfile    " disable swap file

" todo: https://vi.stackexchange.com/questions/12794/how-to-share-config-between-vim-and-neovim
" todo: upgrade these file detection things
autocmd BufReadPost *.rs setlocal filetype=rust
autocmd! BufNewFile,BufRead *.rs setlocal ft=rust
autocmd! BufNewFile,BufRead *.tex setlocal ft=tex
autocmd! BufNewFile,BufRead *.lhs setlocal ft=haskell
autocmd BufRead,BufNewFile *.nix setlocal filetype=nix
autocmd BufRead,BufNewFile *.yml setlocal filetype=yaml
autocmd BufRead,BufNewFile *.yaml setlocal filetype=yaml


autocmd Filetype json setlocal ts=2 sts=2 sw=2
autocmd Filetype haskell setlocal ts=2 sts=2 sw=2
autocmd Filetype arduino setlocal ts=2 sts=2 sw=2
autocmd Filetype yaml setlocal ts=2 sts=2 sw=2
autocmd Filetype bean setlocal ts=2 sts=2 sw=2
autocmd Filetype python setlocal ts=4 sts=4 sw=4
autocmd Filetype cpp setlocal ts=4 sts=4 sw=4
autocmd Filetype c++ setlocal ts=4 sts=4 sw=4
autocmd FileType make setlocal noexpandtab
autocmd FileType rust setlocal ts=4 sts=4 sw=4


" http://stackoverflow.com/questions/4521818/automatically-insert-a-matching-brace-in-vim
autocmd FileType java,cpp,c++,arduino,c inoremap <buffer> { {<CR>}<Esc>ko

" autocmd FileType java ! '/datadisk/java-stuff/eclipse/plugins/org.eclim_2.6.0/eclimd'
" autocmd FileType java PingEclim

highlight colorcolumn ctermbg=red
highlight warn ctermbg=black

" set listchars=tab:>.,trail:.,extends:#,nbsp:.

call matchadd('colorcolumn', '\%101v', 100) " highlighting lines longer than 100 characters in red
" call matchadd('colorcolumn', '\%>100v.', 0) "for it is better that way: highlighting lines longer than 100 characters in red
call matchadd('warn', '\s\+$', 0) " highlighting trailing whitespaces in black


" func! NoEditMode()
"     call matchdelete(g:mc)
"     call matchdelete(g:ms)
" endfu
" com! NoEditMode call NoEditMode()


" set listchars=tab:>.,trail:.,extends:#,nbsp:.

" Saving when switching buffers or making
set autowriteall


"set smartindent
"
" URL: http://vim.wikia.com/wiki/Example_vimrc
" Authors: http://vim.wikia.com/wiki/Vim_on_Freenode
" Description: A minimal, but feature rich, example .vimrc. If you are a
"             newbie, basing your first .vimrc on this file is a good
" choice.
"             If you're a more advanced user, building your own .vimrc
" based
"             on this file is still a good idea.
"
"------------------------------------------------------------
" Features
"
" These options and commands enable some very useful features in Vim, that
" no user should have to live without.
"
" Set 'nocompatible' to ward off unexpected things that your distro might
" have made, as well as sanely reset options when re-sourcing .vimrc
set nocompatible

" Attempt to determine the type of a file based on its name and possibly
"its
"" contents. Use this to allow intelligent auto-indenting for each filetype,
"" and for plugins that are filetype specific.
"filetype indent plugin on
"
" " Enable syntax highlighting
syntax on


"------------------------------------------------------------
" Must have options
"
" These are highly recommended options.
"
"" Vim with default settings does not allow easy switching between
"multiple files
"" in the same editor window. Users can use multiple split windows or
"multiple
"" tab pages to edit multiple files, but it is still best to enable an
"option to
"" allow easier switching between files.
""
"" One such option is the 'hidden' option, which allows you to re-use
"the same
"" window and switch from an unsaved buffer without saving it first.
"Also allows
"" you to keep an undo history for multiple files when re-using the
"same window
"" in this way. Note that using persistent undo also lets you undo in
"multiple
"" files even in the same window, but is less efficient and is
"actually designed
"" for keeping undo history after closing Vim entirely. Vim will
"complain if you
"" try to quit without saving, and swap files will keep you safe if
"your computer
"" crashes.
"set hidden

"" Note that not everyone likes working this way (with the hidden
"option).
"" Alternatives include using tabs or split windows instead of
"re-using the same
" window as mentioned above, and/or either of the following options:
" set confirm
" set autowriteall

"" Better command-line completion
set wildmenu
" set wildmode=list:longest
set wildignore=*.swp,*.bak,*.pyc,*.class,.*,*.hi,*.o
"
" Show partial commands in the last line of the screen
set showcmd

"" Highlight searches (use <C-L> to temporarily turn off
"highlighting; see the
"" mapping of <C-L> below)
set hlsearch
"
" " Modelines have historically been a source of security
" vulnerabilities. As
" " such, it may be a good idea to disable them and use the
" securemodelines
" " script,
" <http://www.vim.org/scripts/script.php?script_id=1876>.
" " set nomodeline

""------------------------------------------------------------
"" Usability options
""
"" These are options that users frequently set in their .vimrc.
"Some of them
"" change Vim's behaviour in ways which deviate from the true
"Vi way, but
"" which are considered to add usability. Which, if any, of
"these options to
"" use is very much a personal preference, but they are
"harmless.

"" Use case insensitive search, except when using capital
"letters
set ignorecase
"set smartcase

" " Allow backspacing over autoindent, line breaks and start
" of insert action
set backspace=indent,eol,start

"" When opening a new line and no filetype-specific
"indenting is enabled, keep
"" the same indent as the line you're currently on. Useful
"for READMEs, etc.
"set autoindent

"" Stop certain movements from always going to the first
"character of a line.
"" While this behaviour deviates from that of Vi, it does
"what most users
"" coming from other editors would expect.
"set nostartofline

"" Display the cursor position on the last line of the
"screen or in the status
"" line of a window
set ruler

" " Always display the status line, even if only one
" window is displayed
set laststatus=2
"
"" Instead of failing a command because of unsaved
"changes, instead raise a
"" dialogue asking if you wish to save changed files.
set confirm
"
" Use visual bell instead of beeping when doing
"something wrong
set visualbell

"" And reset the terminal code for the visual bell. If
"visualbell is set, and
"" this line is also included, vim will neither flash
"nor beep. If visualbell
"" is unset, this does nothing.
"set t_vb=

"" Enable use of the mouse for all modes
"set mouse=a
"
"" Set the command window height to 2 lines, to
"avoid many cases of having to
""press <Enter> to continue"
set cmdheight=2
"
" Display line numbers on the left
set number
"
"" Quickly time out on keycodes, but never time
"out on mappings
"set notimeout ttimeout ttimeoutlen=200

"" Use <F11> to toggle between 'paste' and
"'nopaste'
" set pastetoggle=<F7>

""------------------------------------------------------------
"" Indentation options
""
"" Indentation settings according to personal
"preference.
"
" " Indentation settings for using 4 spaces
" instead of tabs.
" " Do not change 'tabstop' from its default
" value of 8 with this setup.
" set shiftwidth=4
" set softtabstop=4
" set expandtab

" Indentation settings for using hard tabs
"for indent. Display tabs as
" four characters wide.
"set shiftwidth=4
"set tabstop=4
"
"

"------------------------------------------------------------
" Mappings
"
" Useful mappings
"
"" Map Y to act like D and C, i.e. to yank
"until EOL, rather than act as yy,
"" which is the default
"map Y y$
"
" " Map <C-L> (redraw screen) to also turn
" off search highlighting until the
" " next search
nnoremap <C-L> :nohl<CR><C-L>

" explanation: do the following when 'l' is pressed:
" - search in this line for occurences of more than one space, and replace
"   them with one. Do not explicitly error when this is not possible.
" - shorten line respectively, unmatch the two spaces (would be highlighted
"   otherwise)
" - correctly re-indent from last line to end of paragraph
noremap L mk:.s# # #ge<CR>gql<C-L>:nohl<CR>k=}jj={'kj
" vnoremap L gq
" without the paragraph reformatting part:
noremap l mk:.s# # #ge<CR>gql<C-L>:nohl<CR>


" For multi line version you can do this after selecting the text:
"
" :'<,'>:w !command<CR>
" You can map it to simple visual mode shortcut like this:
"

" http://vim.wikia.com/wiki/Highlight_current_line
nnoremap <silent> <Leader>l ml:execute 'match Search /\%'.line('.').'l/'<CR>
nnoremap <silent> <Leader>c :exec '!'.getline('.')<CR>

" from: https://stackoverflow.com/questions/1089028/is-it-possible-to-call-make-in-vim-in-linux-without-showing-the-shell
nnoremap <leader>m :silent make!\|redraw!\|cc<CR>
vnoremap <Leader>r y:!rg "<c-r>""<CR>
vnoremap <Leader>s yjV:s/REPO/<c-r>"/g<CR>
vnoremap <Leader>w <esc>:'<,'>:w !wc<CR>
nnoremap <Leader>w <esc>:%w !wc<CR>

" testing
" [REPO](testurl/REPO)
"


xnoremap <leader>c <esc>:'<,'>:w !fish<CR>
" Hit leader key + c in visual mode to send the selected text to a stdin of the command. stdout of the command will be printed below vim's statusbar.
"
" link:  https://stackoverflow.com/questions/2575545/vim-pipe-selected-text-to-shell-cmd-and-receive-output-on-vim-info-command-line


"
"  "------------------------------------------------------------
"
" Helping for c-files and the like:
"  :make
"
"  :cn  = next error (even other file)
"  :cc  = current error message
"
" $ ctags *.c
"  -> creates tags for all *.c files.
"  vi -t function jumps to function
"  CTRL-] jumps to function definition
"  CTRL-T jumps back one level
"
" http://www.makeuseof.com/tag/5-things-need-put-vim-config-file/
"
" set textwidth=100 " do not allow lines to be longer than 100


" Turn Vim into a Distraction-Free Word Processor
" While Vim is a great text editor for developers, it's also great for those
" who want a simplified, customizable yet distraction-free environment for
" writing.
"
" With a few lines of code, you can configure vim to switch into a "word
" processor" mode when required. This changes how text is formatted in the
" editor, and introduces things like spellchecking.
"
" First, create a function called WordProcessorMode, and include the following
" lines of code.
"
" vim-wordprocessormode
"
" func! WordProcessorMode()
"  setlocal textwidth=80
"  setlocal smartindent
"  setlocal spell spelllang=en_us
"  setlocal noexpandtab
" endfu
" Then, you're going to need to define how you'll activate it. The
" following line of code allows you to create a command. When in command
" mode, if you call "WP", it will activate word processor mode.
"
" vim-callwordprocessormode
"
" com! WP call WordProcessorMode()
" To test that it works, open a new text file in VIM, and press escape.
" Then type "WP", and hit enter. Then, type some text, with some words
" intentionally spelled incorrectly. If VIM highlights them as incorrect,
" then you know you've installed it correctly.

" http://vim.wikia.com/wiki/Highlight_current_line
nnoremap <silent> <Leader>l ml:execute 'match Search /\%'.line('.').'l/'<CR>
nnoremap <silent> <Leader>c :exec '!'.getline('.')<CR>

" from: https://stackoverflow.com/questions/1089028/is-it-possible-to-call-make-in-vim-in-linux-without-showing-the-shell
nnoremap <leader>m :silent make!\|redraw!\|cc<CR>

" http://usevim.com/2014/12/03/conoline/
" autocmd WinEnter * setlocal cursorcolumn
" autocmd WinLeave * setlocal nocursorcolumn


nnoremap <F2> :buffers<CR>:buffer<Space>
map <F3> :Run<CR>
map <silent> <F4> :call ToggleBetweenHeaderAndSourceFile()<CR>
map <F5> :!git fetch --all; git stash; git pull -r; git stash pop; git push<CR>
map <F6> :!git add %<CR>
" set pastetoggle=<F6>
map <F7> :!git commit -m ""
map <F8> :Interactive<CR>
map <F9> :Build<CR>
map <F10> :Test<CR>
map <F12> :make -j6<CR>

" <S-F5>
map <F17> :!git push<CR>
" set <S-F12>=^[[24;2~
" map <S-F12> :make -j6<CR>
map <F24> :silent make!\|redraw!\|cc<CR>


" func! WordProcessorMode()
"    setlocal textwidth=120
"    setlocal smartindent
"    setlocal spell spelllang=en_us
" "   setlocal spell spelllang=de_de
"    setlocal noexpandtab
" endfu
" com! WP call WordProcessorMode()


" func! WordProcessorModeOFF()
"    setlocal textwidth&
"    setlocal smartindent&
"    setlocal nospell
" "   setlocal spell spelllang=de_de
"    setlocal noexpandtab&
" endfu
" com! WO call WordProcessorModeOFF()




" http://ad-wiki.informatik.uni-freiburg.de/teaching/ProgrammierenCplusplusSS2010/Editor?action=AttachFile&do=view&target=vimrc.txt
"" Toggle between .h and .cpp with F4.
function! ToggleBetweenHeaderAndSourceFile()
  write
  let bufname = bufname("%")
  let ext = fnamemodify(bufname, ":e")
  if ext == "h"
    let ext = "cpp"
  elseif ext == "cpp"
    let ext = "h"
  else
    return
  endif
  let bufname_new = fnamemodify(bufname, ":r") . "." . ext
  let bufname_alt = bufname("#")
  if bufname_new == bufname_alt
    execute ":e#"
  else
    execute ":e " . bufname_new
  endif
endfunction

set showmatch
"" No blinking cursor please.
set gcr=a:blinkon0



func! Trim()
    %s/\s\+$//e
    %s/\    /    /e
endfu
com! Trim call Trim()

func! Ghci()
    silent !stack ghci %
endfu
com! G call Ghci()

func! Ghci2()
    silent !cabal exec -- ghci %
endfu
com! Hask call Ghci2()


func! Python()
    silent !python %
endfu
com! P call Python()


func! IPython()
    silent !ipython3 --colors=LightBG -i %
endfu
com! IP call IPython()

func! Tex()
    let texfile = expand('%:h') . '/main.tex'
    execute "!pdflatex --output-directory='%:h' " texfile
    " let newfile = './' . expand('%:h') . '/' . expand('%:t:r') . ".pdf"
        " returns the current filename (without suffix), relatively speaking
    let newfile = './' . expand('%:h') . "/main.pdf"
    execute "silent !evince -s " newfile " &"
        " starting evince in presentation mode
endfu
com! Tex call Tex()

fun! NXC()
    !nbc -S$(nexttool -listbricks) -r %
endfu
com! NXC call NXC()





func! Run()
    let extension = expand('%:e') " returns the extension (without dot) only
    if extension == 'rs' || extension == 'toml'
        !cargo run
    else
        make run
    endif
    sleep 1
    redraw!
endfu

com! Run call Run()

func! Interactive()
    let extension = expand('%:e') " returns the extension (without dot) only
    if extension == 'hs' || extension == 'lhs'
        G
    elseif extension == 'py'
        IP
    elseif extension == 'tex'
        Tex
    elseif extension == 'nxc'
        NXC
    elseif extension == 'java'
        JavaCorrect
    elseif extension == 'cpp' || extension == 'h'
        make test
    elseif extension == 'rs' || extension == 'toml'
        !cargo run
    else
        echo "No Interactive default for extension \"" . extension . "\" yet"
    endif
    sleep 1
    redraw!
endfu

com! Interactive call Interactive()


func! Build()
    write
    let extension = expand('%:e') " returns the extension (without dot) only
    if extension == 'tex'
        " let newfile = './' . expand('%:h') . '/' . expand('%:t:r') . ".pdf"
        let newfile = './' . expand('%:h') . "/main.pdf"
        execute "silent !evince -s " newfile " &"
        " starting evince in presentation mode on page n
    elseif extension == 'java'
        " Java
        " quit
        let thisfile = %
        !javac list-operations/src/listoperations/Main.java -d list-operations/bin/
        !java -cp list-operations/bin/ listoperations.Main
    elseif extension == 'cpp' || extension == 'h'
        make plot
    elseif extension == 'rs' || extension == 'toml'
        !cargo build
    elseif extension == 'hs'
        !stack build
    elseif extension == 'cs'
        !mdtool build "Singularity/Singularity.csproj"
        !mdtool build "Singularity/Singularity/Singularity.csproj"
    else
        echo "No Build default for extension \"" . extension . "\" yet"
    endif
    sleep 1

endfu

com! Build call Build()



func! Test()
    write
    let extension = expand('%:e') " returns the extension (without dot) only
    if extension == 'hs'
        "Hask
        !stack test
    elseif extension == 'py'
        echo "\n"
        silent !pep8 %
        !flake8 %
    elseif extension == 'tex'
        silent !pdflatex --output-directory='%:h'  %
    elseif extension == 'nxc'
        ownsyntax c
    elseif extension == 'java'
        Checkstyle
    elseif extension == 'cpp' || extension == 'h'
        make checkstyle
    elseif extension == 'rs' || extension == 'toml'
"        !cargo check
        !cargo test
    elseif extension == 'cs'
        !git blame %
    else
        echo "No Test default for extension \"" . extension . "\" yet"
    endif
    sleep 1
    redraw!
endfu

com! Test call Test()


com! Ct call checktime

" Tipp: CTRL-a increases the underlying number,
" CTRL-x decreases the underlying number

" macros can be saved like this:
" "<macrobuffer>p

" source: https://vim.fandom.com/wiki/Switching_case_of_characters#Twiddle_case
function! TwiddleCase(str)
  if a:str ==# toupper(a:str)
    let result = tolower(a:str)
  elseif a:str ==# tolower(a:str)
    let result = substitute(a:str,'\(\<\w\+\>\)', '\u\1', 'g')
  else
    let result = toupper(a:str)
  endif
  return result
endfunction
vnoremap ~ y:call setreg('', TwiddleCase(@"), getregtype(''))<CR>gv""Pgv


" LaTeX Macros:
let @f = 'o\begin{frame}[c]\end{frame}kA    '
let @i = 'o\begin{itemize}[<+(1)->]\item \end{itemize}kA'
let @c = 'o\begin{columns}\begin{column}{0.5\textwidth}\end{column}\begin{column}{0.5\textwidth}\end{column}\end{columns}5k'
let @o = 'o\begin{overlayarea}{\textheight}{\textwidth}\end{overlayarea}'
let @b = 'o\begin{qblock}{}\end{qblock}kk$i'


colorscheme koehler



" install vim-plug if not yet installed
if empty(glob("$HOME/.local/share/nvim/site/autoload/plug.vim"))
  echo 'installing vim-plug'
  silent !curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs
              \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif




" install plugins with: PlugInstall
" update with: PlugUpdate
" call plug#begin(stdpath('data') . '/plugged')
call plug#begin('~/.config/nvimplugins')

Plug 'editorconfig/editorconfig-vim'
Plug 'fkarg/todo.txt-vim'
Plug 'nathangrigg/vim-beancount'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'LnL7/vim-nix'

call plug#end()
