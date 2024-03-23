if !has('vim9script') ||  v:version < 901
    echoerr 'Needs Vim version 9.1 and above'
    finish
endif
vim9script

g:loaded_scope = true

import autoload '../autoload/scope/fuzzy.vim'

# ripgrep output can include column number. default values of grepformat does
# not contain column pattern, add it.
set grepformat^=%f:%l:%c:%m

var cmds = [
    'Autocmd',
    'BufSearch',
    'Buffer',
    'CmdHistory',
    'Colorscheme',
    'Command',
    'File',
    'Filetype',
    'GitFile',
    'Grep',
    'Help',
    'Highlight',
    'Jumplist',
    'Keymap',
    'LspDocumentSymbol',
    'Loclist',
    'LoclistHistory',
    'MRU',
    'Mark',
    'Option',
    'Quickfix',
    'QuickfixHistory',
    'Register',
    'Tag',
    'Window',
]

def DoCommand(cmd: string)
    $'fuzzy.{(cmd->split())[0]}()'->eval()
enddef

def Completer(prefix: string, line: string, cursorpos: number): string
    var parts = line->split()
    if parts->len() == 1
        return cmds->copy()->join("\n")
    elseif parts[1] =~ $'^{prefix}'
        return cmds->copy()->filter((_, v) => v =~? $'^{prefix}')->join("\n")
    endif
    return null_string
enddef

command -nargs=1 -complete=custom,Completer Scope DoCommand(<f-args>)
