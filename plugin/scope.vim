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

def DoCommand(fnstr: string, arg1: string = null_string)
    def ExecCmd(dir: string, ExecFn: func(): any)
        try
            :silent exe $'cd {dir}'
            ExecFn()
        finally
            :silent cd -
        endtry
    enddef
    const cidx = cmds->indexof((_, v) => v ==? fnstr)
    if cidx != -1
        if fnstr ==? 'file'
            if arg1->isdirectory()
                ExecCmd(arg1, (): any => fuzzy.File())
            else
                fuzzy.File()
            endif
        elseif fnstr ==? 'grep'
            # 'cd dir' does not work for grep since grep is called after 'cd -' is called (above)
            fuzzy.Grep(null_string, true, arg1)
        else
            $'fuzzy.{cmds[cidx]}()'->eval()
        endif
    endif
enddef

def Completor(prefix: string, line: string, cursorpos: number): string
    if prefix == null_string
        return cmds->copy()->join("\n")
    else
        const parts = line->strpart(0, cursorpos)->split()
        if parts->len() == 2
            return cmds->copy()->filter((_, v) => v =~? $'^{prefix}')->join("\n")
        elseif parts->len() == 3 && parts[1] ==? 'file'
            return parts[2]->getcompletion('dir')->join("\n")
        endif
    endif
    return null_string
enddef

command -nargs=+ -complete=custom,Completor Scope DoCommand(<f-args>)
