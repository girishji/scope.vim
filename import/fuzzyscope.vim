vim9script

import '../autoload/scope/fuzzy.vim' as fz
import '../autoload/scope/task.vim'
import '../autoload/scope/popup.vim'

export def AsyncCmdFactory(cmd: any, CallbackFn: func(list<string>), env: dict<any> = null_dict): task.AsyncCmd
    return task.AsyncCmd.new(cmd, CallbackFn, env)
enddef

export def FilterMenuFactory(title: string, items_dict: list<dict<any>>, Callback: func(any, string), Setup: func(number, number) = null_function, GetItems: func(list<any>, string): list<any> = null_function): popup.FilterMenu
    return popup.FilterMenu.new(title, items_dict, Callback, Setup, GetItems)
enddef

export def FuzzyFactory(): fz.Fuzzy
    return fz.Fuzzy.new()
enddef

export var fuzzy = fz.Fuzzy.new()
