vim9script

import './task.vim'
import './popup.vim'

export var options: dict<any> = {
    grep_echo_cmd: true,
}

export def OptionsSet(opt: dict<any>)
    options->extend(opt)
enddef

export def FilterItems(lst: list<dict<any>>, prompt: string): list<any>
    def PrioritizeFilename(matches: list<any>): list<any>
        # prefer matching filenames over matching directory names
        var filtered = [[], [], []]
        var pat = prompt->trim()
        for Filterfn in [(x, y) => x =~ y, (x, y) => x !~ y]
            for [i, v] in matches[0]->items()
                if Filterfn(v.text->fnamemodify(':t'), $'^{pat}')
                    filtered[0]->add(matches[0][i])
                    filtered[1]->add(matches[1][i])
                    filtered[2]->add(matches[2][i])
                endif
            endfor
        endfor
        return filtered
    enddef
    if prompt->empty()
        return [lst, [lst]]
    else
        var pat = prompt->trim()
        # var matches = lst->matchfuzzypos(pat, {key: "text", limit: 1000})
        var matches = lst->matchfuzzypos(pat, {key: "text"})
        if matches[0]->empty() || pat =~ '\s'
            return [lst, matches]
        else
            return [lst, PrioritizeFilename(matches)]
        endif
    endif
enddef

export def FindCmdExcludeDirs(): string
    # exclude dirs from .config/fd/ignore and .gitignore
    # var sep = has("win32") ? '\' : '/'
    var excludes = []
    var ignore_files = [getenv('HOME') .. '/.config/fd/ignore', '.gitignore']
    for ignore in ignore_files
        if ignore->filereadable()
            excludes->extend(readfile(ignore)->filter((_, v) => v != '' && v !~ '^#'))
        endif
    endfor
    var exclcmds = []
    for item in excludes
        var idx = item->strridx('/')
        if idx == item->len() - 1
            exclcmds->add($'-type d -path */{item}* -prune')
        else
            exclcmds->add($'-path */{item}/* -prune')
        endif
    endfor
    var cmd = 'find . ' .. (exclcmds->empty() ? '' : exclcmds->join(' -o '))
    return cmd .. ' -o -name *.swp -prune -o -path */.* -prune -o -type f -print -follow'
enddef

export def FindCmd(): list<any>
    if executable('fd')
        return 'fd -tf --follow'->split()
    else
        var cmd = ['find', '.']
        for fname in ['*.zwc', '*.swp', '.DS_Store']
            cmd->extend(['-name', fname, '-prune', '-o'])
        endfor
        for fname in ['.git']  # matches .git/ and .gitrc through */git*
            cmd->extend(['-path', $'*/{fname}*', '-prune', '-o'])
        endfor
        for dname in ['plugged', '.zsh_sessions']
            cmd->extend(['-type', 'd', '-path', $'*/{dname}*', '-prune', '-o'])
        endfor
        return cmd->extend(['-type', 'f', '-print', '-follow'])
    endif
enddef

# fuzzy find files (build a list of files once and then fuzzy search on them)
export def File(findCmd: string = null_string, count: number = 10000)  # list at least 10k files to search on
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("File", [],
        (res, key) => {
            if key == "\<C-j>"
                exe $"split {res.text}"
            elseif key == "\<C-v>"
                exe $"vert split {res.text}"
            elseif key == "\<C-t>"
                exe $"tabe {res.text}"
            else
                exe $"e {res.text}"
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuDirectorySubtle Comment
        },
        FilterItems)

    var job: task.AsyncCmd
    var workaround = false
    job = task.AsyncCmd.new(findCmd == null_string ? FindCmd() : findCmd->split(),
        (items: list<string>) => {
            if menu.Closed()
                job.Stop()
            endif
            if items->len() < 200
                items->sort()
            endif
            var items_dict: list<dict<any>>
            if items->len() < 1
                items_dict = [{text: ""}]
            else
                items_dict = items->mapnew((_, v) => {
                    return {text: v}
                })
            endif
            if !menu.SetText(items_dict, FilterItems, count)
                job.Stop()
            endif
            if !workaround
                feedkeys("\<bs>", "nt")  # workaround for https://github.com/vim/vim/issues/13932
                workaround = true
            endif
        })
enddef

def GrepCmd(): string
    var cmd = 'grep --color=never -RESIHin --exclude="*.git*" --exclude="*.swp" --exclude="*.zwc" --exclude-dir=plugged'
    return &grepprg ?? cmd
enddef

var prev_grep = null_string

# live grep, not fuzzy search.
# before typing <space> use '\' to escape.
# (grep pattern is: grep <pat> <path1, path2, ...>, so it will interpret second
# word as path)
#
# `ignorecase` argument ensures case-insensitive text highlighting in the popup
# window. Incorporating colored `grep` output into Vim is a challenge. Instead
# of parsing color codes, Vim's syntax highlighting is used. As Vim lacks
# awareness of `grep`'s ignore-case flag, explicit instruction is needed for
# accurate highlighting.
export def Grep(grepcmd: string = '', ignorecase: bool = true)
    var menu: popup.FilterMenu

    def DoGrep(prompt: string, timer: number)
        # during pasting from clipboard to prompt window, spawning a new job for
        # every character input causes hiccups. return the control back to Vim's
        # main loop and let typehead catch up.
        if menu.prompt != prompt
            timer_start(1, function(DoGrep, [menu.prompt]))
            return
        endif
        prev_grep = prompt
        win_execute(menu.id, "syn clear ScopeMenuMatch")
        if options.grep_echo_cmd
            echo ''
        endif
        if prompt != null_string
            var cmd = (grepcmd ?? GrepCmd()) .. ' ' .. prompt
            cmd = cmd->escape('*')
            if options.grep_echo_cmd
                echo cmd
            endif
            # do not convert cmd to list, as this will not quote space characters correctly.
            var job: task.AsyncCmd
            job = task.AsyncCmd.new(cmd,
                (items: list<string>) => {
                    if menu.Closed()
                        job.Stop()
                    endif
                    var items_dict: list<dict<any>>
                    if items->len() < 1
                        items_dict = [{text: ""}]
                    else
                        items_dict = items->mapnew((_, v) => {
                            return {text: v}
                        })
                    endif
                    if !menu.SetText(items_dict,
                            (_, _): list<any> => {
                                return [items_dict, [items_dict]]
                            }, 100)  # max 100 items, and then kill the job
                        job.Stop()
                    endif
                })
            var pat = prompt->escape('~')
            if pat[-1 : -1] == '\'
                pat = $'{pat}\'
            endif
            if ignorecase
                win_execute(menu.id, $"syn match ScopeMenuMatch \"\\c{pat}\"")
            else
                win_execute(menu.id, $"syn match ScopeMenuMatch \"{pat}\"")
            endif
        endif
    enddef

    menu = popup.FilterMenu.new('Grep', [],
        (res, key) => {
            var fl = res.text->split()[0]->split(':')
            if key == "\<C-j>"
                exe $"split +{fl[1]} {fl[0]}"
            elseif key == "\<C-v>"
                exe $"vert split +{fl[1]} {fl[0]}"
            elseif key == "\<C-t>"
                exe $"tabe +{fl[1]} {fl[0]}"
            else
                exe $":e +{fl[1]} {fl[0]}"
            endif
        },
        (id, idp) => {
            win_execute(id, $"syn match ScopeMenuFilenameSubtle \".*:\\d\\+:\"")
            # note: it is expensive to regex match. even though following pattern
            #   is more accurate vim throws 'redrawtime exceeded' and stops
            # win_execute(menu.id, $"syn match FilterMenuMatch \"[^:]\\+:\\d\\+:\"")
            hi def link ScopeMenuFilenameSubtle Comment
            if prev_grep != null_string
                idp->popup_settext($'{popup.options.promptchar} {prev_grep}')
                idp->clearmatches()
                matchaddpos('ScopeMenuCursor', [[1, 3]], 10, -1, {window: idp})
                matchaddpos('ScopeMenuVirtualText', [[1, 4, 999]], 10, -1, {window: idp})
            endif
        },
        (lst: list<dict<any>>, prompt: string): list<any> => {
            # This function is called everytime when user types something
            timer_start(1, function(DoGrep, [prompt]))
            return [[], [[]]]
        },
        () => {
            if options.grep_echo_cmd
                echo ''
            endif
        }, true)
enddef

export def Buffer(list_all_buffers: bool = false)
    var blist = list_all_buffers ? getbufinfo({buloaded: 1}) : getbufinfo({buflisted: 1})
    var buffer_list = blist->mapnew((_, v) => {
        return {bufnr: v.bufnr,
            text: (bufname(v.bufnr) ?? $'[{v.bufnr}: No Name]'),
            lastused: v.lastused,
            winid: len(v.windows) > 0 ? v.windows[0] : -1}
    })->sort((i, j) => i.lastused > j.lastused ? -1 : i.lastused == j.lastused ? 0 : 1)
    # Alternate buffer first, current buffer second
    if buffer_list->len() > 1 && buffer_list[0].bufnr == bufnr()
        [buffer_list[0], buffer_list[1]] = [buffer_list[1], buffer_list[0]]
    endif
    popup.FilterMenu.new("Buffer", buffer_list,
        (res, key) => {
            if key == "\<c-t>"
                exe $":tab sb {res.bufnr}"
            elseif key == "\<c-j>"
                exe $":sb {res.bufnr}"
            elseif key == "\<c-v>"
                exe $":vert sb {res.bufnr}"
            else
                if res.winid != -1
                    win_gotoid(res.winid)
                else
                    exe $":b {res.bufnr}"
                endif
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuDirectorySubtle Comment
        },
        FilterItems)
enddef

# export def DoVimItems(title: string, cmd: string, GetItemsFn: function(string): list<string>)
export def DoVimItems(title: string, cmd: string, GetItemsFn: func(string): list<string>)
    var menu: popup.FilterMenu

    def DoCompletionItems(prompt: string, timer: number)
        if menu.prompt != prompt
            # to avoid hiccups when pasting from clipboard, return the control back to Vim's
            # main loop and let typehead catch up.
            timer_start(1, function(DoCompletionItems, [menu.prompt]))
            return
        endif
        win_execute(menu.id, "syn clear ScopeMenuMatch")
        var items_dict: list<dict<any>> = []
        if prompt != null_string
            items_dict = GetItemsFn(prompt)->mapnew((_, v) => {
                return {text: v}
                })
            menu.SetText(items_dict,
                (_, _): list<any> => {
                return [items_dict, [items_dict]]
                }, 100)  # max 100 items
            var pat = prompt->escape('~')
            win_execute(menu.id, $"syn match ScopeMenuMatch \"\\c{pat}\"")
        endif
    enddef

    menu = popup.FilterMenu.new(title, [],
        (res, key) => {
            if key == "\<c-t>"
                exe $":tab {cmd} {res.text}"
            elseif key == "\<c-v>"
                exe $":vert {cmd} {res.text}"
            else
                echom $":{cmd} {res.text}"
                exe $":{cmd} {res.text}"
            endif
        },
        null_function,
        (lst: list<dict<any>>, prompt: string): list<any> => {
            timer_start(1, function(DoCompletionItems, [menu.prompt]))
            return [[], [[]]]
        }, null_function, true)
enddef

def GetCompletionItems(s: string, type: string): list<string>
    var saved = &wildoptions
    var items: list<string> = []
    try
        :set wildoptions=fuzzy
        items = getcompletion(s, type)
    finally
        exe $'set wildoptions={saved}'
    endtry
    return items
enddef

export def Help()
    DoVimItems('Help', 'help', (p: string) => GetCompletionItems(p, 'help'))
enddef

export def Tag()
    DoVimItems('Tag', 'tag', (p: string) => GetCompletionItems(p, 'tag'))
enddef

export def CscopeEgrep()
    DoVimItems('Cscope egrep', 'edit', (p: string) => {
        return execute($'cscope find e {p}')->split("\n")
       })
enddef

export def VimCommand()
    var cmds = getcompletion('', 'command')->mapnew((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Commands", cmds,
        (res, key) => {
            exe $":{res.text}"
        })
enddef

export def Keymap()
    var items = execute('map')->split("\n")->mapnew((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Keymap", items,
        (res, key) => {
            })
enddef

export def MRU()
    var mru = []
    if has("win32")
        # windows is very slow checking if file exists
        # use non-filtered v:oldfiles
        mru = v:oldfiles
    else
        mru = v:oldfiles->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    endif
    mru->map((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("MRU", mru,
        (res, key) => {
            if key == "\<c-t>"
                exe $":tabe {res.text}"
            elseif key == "\<c-j>"
                exe $":split {res.text}"
            elseif key == "\<c-v>"
                exe $":vert split {res.text}"
            else
                exe $":e {res.text}"
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuDirectorySubtle Comment
        })
enddef

export def Template()
    var path = $"{fnamemodify($MYVIMRC, ':p:h')}/templates/"
    var ft = getbufvar(bufnr(), '&filetype')
    var ft_path = path .. ft
    var tmpls = []

    if !empty(ft) && isdirectory(ft_path)
        tmpls = mapnew(readdirex(ft_path, (e) => e.type == 'file'), (_, v) => $"{ft}/{v.name}")
    endif

    if isdirectory(path)
        extend(tmpls, mapnew(readdirex(path, (e) => e.type == 'file'), (_, v) => v.name))
    endif

    tmpls->map((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Template",
        tmpls,
        (res, key) => {
            append(line('.'), readfile($"{path}/{res.text}")->mapnew((_, v) => {
                return v->substitute('!!\(.\{-}\)!!', '\=eval(submatch(1))', 'g')
            }))
            if getline('.') =~ '^\s*$'
                del _
            else
                normal! j^
            endif
        })
enddef

export def JumpToWord()
    var word = expand("<cword>")
    if empty(trim(word)) | return | endif
    var lines = []
    for nr in range(1, line('$'))
        var line = getline(nr)
        if line->stridx(word) > -1
            lines->add({text: $"{line} ({nr})", linenr: nr})
        endif
    endfor
    popup.FilterMenu.new($'Jump to "{word}"', lines,
        (res, key) => {
            exe $":{res.linenr}"
            normal! zz
        },
        (winid, _) => {
            win_execute(winid, 'syn match ScopeMenuLineNr "(\d\+)$"')
            hi def link ScopeMenuLineNr Comment
        })
enddef

export def GitFile(path: string = "")
    var path_e = path->empty() ? "" : $"{path}/"
    var git_cmd = 'git ls-files --other --full-name --cached --exclude-standard'
    var cd_cmd = path->empty() ? "" : $"cd {path} && "
    var git_files = systemlist($'{cd_cmd}{git_cmd}')->mapnew((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Git File", git_files,
        (res, key) => {
            if key == "\<c-t>"
                exe $":tabe {path_e}{res.text}"
            elseif key == "\<c-j>"
                exe $":split {path_e}{res.text}"
            elseif key == "\<c-v>"
                exe $":vert split {path_e}{res.text}"
            else
                exe $":e {path_e}{res.text}"
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuDirectorySubtle Comment
        })
enddef

export def Colorscheme()
    popup.FilterMenu.new("Colorscheme",
        getcompletion("", "color")->mapnew((_, v) => {
            return {text: v}
        }),
        (res, key) => {
            exe $":colorscheme {res.text}"
        },
        (winid, _) => {
            if exists("g:colors_name")
                win_execute(winid, $'syn match ScopeMenuCurrent "^{g:colors_name}$"')
                hi def link ScopeMenuCurrent Statement
            endif
        })
enddef

export def Filetype()
    var ft_list = globpath(&rtp, "ftplugin/*.vim", 0, 1)
        ->mapnew((_, v) => ({text: fnamemodify(v, ":t:r")}))
        ->sort()
        ->uniq()
    popup.FilterMenu.new("Filetype", ft_list,
        (res, key) => {
            exe $":set ft={res.text}"
        })
enddef

export def Highlight()
    var hl = hlget()->mapnew((_, v) => {
        if v->has_key("cleared")
            return {text: $"xxx {v.name} cleared", name: v.name,
                value: $"hi {v.name}"}
        elseif v->has_key("linksto")
            return {text: $"xxx {v.name} links to {v.linksto}", name: v.name,
                value: $"hi link {v.name} {v.linksto}"}
        else
            var term = v->has_key('term') ? $' term={v.term->keys()->join(",")}' : ''
            var ctermfg = v->has_key('ctermfg') ? $' ctermfg={v.ctermfg}' : ''
            var ctermbg = v->has_key('ctermbg') ? $' ctermbg={v.ctermbg}' : ''
            var cterm = v->has_key('cterm') ? $' cterm={v.cterm->keys()->join(",")}' : ''
            var guifg = v->has_key('guifg') ? $' guifg={v.guifg}' : ''
            var guibg = v->has_key('guibg') ? $' guibg={v.guibg}' : ''
            var gui = v->has_key('gui') ? $' gui={v.gui->keys()->join(",")}' : ''
            return {text: $"xxx {v.name}{guifg}{guibg}{gui}{ctermfg}{ctermbg}{cterm}{term}",
                name: v.name,
                value: $"hi {v.name}{guifg}{guibg}{gui}{ctermfg}{ctermbg}{cterm}{term}"}
        endif
    })
    popup.FilterMenu.new("Highlight", hl,
        (res, key) => {
            feedkeys($":{res.value}\<C-f>")
        },
        (winid, _) => {
            win_execute(winid, 'syn match ScopeMenuHiLinksTo "\(links to\)\|\(cleared\)"')
            hi def link ScopeMenuHiLinksTo Comment
            for h in hl
                win_execute(winid, $'syn match {h.name} "^xxx\ze {h.name}\>"')
            endfor
        })
enddef

export def CmdHistory()
    var cmd_history = [{text: histget("cmd")}] + range(1, histnr("cmd"))->mapnew((i, _) => {
        return {text: histget("cmd", i), idx: i}
    })->filter((_, v) => v.text !~ "^\s*$")->sort((el1, el2) => el1.idx == el2.idx ? 0 : el1.idx > el2.idx ? -1 : 1)
    popup.FilterMenu.new("Command History", cmd_history,
        (res, key) => {
            if key == "\<c-j>"
                feedkeys($":{res.text}\<C-f>", "n")
            else
                feedkeys($":{res.text}\<CR>", "nt")
            endif
        })
enddef

export def Window()
    var windows = []
    for w_info in getwininfo()
        var tabtext = tabpagenr('$') > 1 ? $"Tab {w_info.tabnr}, " : ""
        var wintext = $"Win {w_info.winnr}"
        var name = empty(bufname(w_info.bufnr)) ? "[No Name]" : bufname(w_info.bufnr)
        var current_sign = w_info.winid == win_getid() ? "*" : " "
        windows->add({text: $"{current_sign}({tabtext}{wintext}): {name} ({w_info.winid})", winid: w_info.winid})
    endfor
    popup.FilterMenu.new($'Jump window', windows,
        (res, key) => {
            win_gotoid(res.winid)
        },
        (winid, _) => {
            win_execute(winid, 'syn match ScopeMenuRegular "^ (.\{-}):.*(\d\+)$" contains=ScopeMenuBraces')
            win_execute(winid, 'syn match ScopeMenuCurrent "^\*(.\{-}):.*(\d\+)$" contains=ScopeMenuBraces')
            win_execute(winid, 'syn match ScopeMenuBraces "(\d\+)$" contained')
            win_execute(winid, 'syn match ScopeMenuBraces "^[* ](.\{-}):" contained')
            hi def link ScopeMenuBraces Comment
            hi def link ScopeMenuCurrent Statement
        })
enddef

# chunks of code shamelessly ripped from habamax
# https://github.com/habamax/.vim/blob/master/autoload/fuzzy.vim
