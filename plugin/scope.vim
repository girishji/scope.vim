if !has('vim9script') ||  v:version < 901
    echoerr 'Needs Vim version 9.1 and above'
    finish
endif
vim9script

g:loaded_scope = true

import autoload '../autoload/scope/popup.vim'

def! g:ScopePopupOptionsSet(opt: dict<any>)
    popup.options->extend(opt)
enddef
