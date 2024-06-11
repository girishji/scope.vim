vim9script

import './fuzzy.vim'

const cmds = [
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
    'HelpfilesGrep',
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

export def DoCommand(fnstr: string, arg1: string = null_string, arg2: string = null_string)
    const cidx = cmds->indexof((_, v) => v ==? fnstr)
    if cidx != -1
        if fnstr ==? 'grep'
            if arg1->isdirectory()
                # 'cd dir' does not work for grep since grep is called after 'cd -' is called (above)
                fuzzy.Grep(null_string, true, arg2, arg1)
            else
                fuzzy.Grep(null_string, true, $'{arg1}{arg2 != null_string ? " " : ""}{arg2}')
            endif
        else
            $'fuzzy.{cmds[cidx]}()'->eval()
        endif
    endif
enddef

export def Completor(prefix: string, line: string, cursorpos: number): string
    if prefix == null_string
        return cmds->copy()->join("\n")
    else
        var stripped = line->substitute('vim9\S*\s', '', '')
        const parts = stripped->strpart(0, cursorpos)->split()
        if parts->len() == 2
            return cmds->copy()->filter((_, v) => v =~? $'^{prefix}')->join("\n")
        elseif parts->len() == 3 && parts[1] =~? 'file\|grep'
            return parts[2]->getcompletion('dir')->join("\n")
        endif
    endif
    return null_string
enddef
