vim9script

import '../autoload/fuzzy.vim'
import '../autoload/popup.vim'
import '../autoload/task.vim'

export def FilterMenuFactory(title: string, items_dict: list<dict<any>>, Callback: func(any, string), Setup: func(number) = null_function, GetItems: func(list<any>, string): list<any> = null_function): popup.FilterMenu
    return popup.FilterMenu.new(title, items_dict, Callback, Setup, GetItems)
enddef

export def AsyncCmdFactory(cmd: any, CallbackFn: func(list<string>), env: dict<any> = null_dict): task.AsyncCmd
    return task.AsyncCmd.new(cmd, CallbackFn, env)
enddef

export def FuzzyFactory(): fuzzy.Fuzzy
    return fuzzy.Fuzzy.new()
enddef

export var fn = fuzzy.Fuzzy.new()
