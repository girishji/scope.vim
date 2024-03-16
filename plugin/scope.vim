if !has('vim9script') ||  v:version < 901
    echoerr 'Needs Vim version 9.1 and above'
    finish
endif
vim9script

g:loaded_scope = true

# ripgrep output can include column number. default values of grepformat does
# not contain column pattern, add it.
set grepformat^=%f:%l:%c:%m
