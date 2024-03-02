vim9script

import autoload 'fuzzy.vim'
import '../autoload/popup.vim'
import '../autoload/task.vim'

export def FilterMenuFactory(title: string, items_dict: list<dict<any>>, Callback: func(any, string), Setup: func(number) = null_function, GetItems: func(list<any>, string): list<any> = null_function): popup.FilterMenu
    return popup.FilterMenu.new(title, items_dict, Callback, Setup, GetItems)
enddef

export def AsyncCmdFactory(cmd: any, CallbackFn: func(list<string>), env: dict<any> = null_dict): task.AsyncCmd
    return task.AsyncCmd(cmd, CallbackFn, env)
enddef

# fuzzy find files (build a list of files once and then fuzzy search on them)
export def File(findCmd: string = '', count: number = 10000)  # list at least 10k files to search on
    fuzzy.File(findCmd)
enddef

# live grep, not fuzzy search. for space use '\ '.
# cannot use >1 words unless spaces are escaped (grep pattern
#   is: grep <pat> <path1, path2, ...>, so it will interpret second word as path)
export def Grep(grepcmd: string = '')
    fuzzy.Grep(grepcmd)
enddef

export def Buffer(list_all_buffers: bool = false)
    fuzzy.Buffer(list_all_buffers)
enddef

export def Keymap()
    fuzzy.Keymap()
enddef

export def MRU()
    fuzzy.MRU()
enddef

export def Template()
    fuzzy.Template()
enddef

export def JumpToWord()
    fuzzy.JumpToWord()
enddef
