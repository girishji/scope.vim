if !has('vim9script') ||  v:version < 901
    echoerr 'Needs Vim version 9.1 and above'
    finish
endif
vim9script

g:loaded_scope = true

import autoload '../autoload/scope/command.vim'

# ripgrep output can include column number. default values of grepformat does
# not contain column pattern, add it.
set grepformat^=%f:%l:%c:%m

command -nargs=+ -complete=custom,command.Completor Scope command.DoCommand(<f-args>)

# Disable bracketed paste (otherwise pasting from clipboard does not work in popup)
# https://github.com/vim/vim/issues/11766
g:scope_bracketed_paste = false

augroup ScopeAutoCmds | autocmd!
    au VimEnter * {
        if !g:scope_bracketed_paste
            &t_BE = ""
            &t_BD = "\e[?2004l"
            exec "set t_PS=\e[200~"
            exec "set t_PE=\e[201~"
        endif
    }
augroup END
