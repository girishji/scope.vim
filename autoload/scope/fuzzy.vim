vim9script

import './task.vim'
import './popup.vim'
import './util.vim'

export var options: dict<any> = {
    grep_echo_cmd: true,
}

export def OptionsSet(opt: dict<any>)
    options->extend(opt)
enddef

# fuzzy find files (build a list of files once and then fuzzy search on them)
export def File(findCmd: string = null_string, count: number = 10000)  # list at least 10k files to search on
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("File", [],
        (res, key) => {
            util.VisitFile(key, res.text)
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuDirectorySubtle ScopeMenuSubtle
        },
        util.FilterItems)

    var job: task.AsyncCmd
    var workaround = false
    job = task.AsyncCmd.new(findCmd == null_string ? util.FindCmd() : findCmd->split(),
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
                    return {text: v, cmd: 'find'}
                })
            endif
            if !menu.SetText(items_dict, util.FilterItems, count)
                job.Stop()
            endif
            if !workaround
                feedkeys("\<bs>", "nt")  # workaround for https://github.com/vim/vim/issues/13932
                workaround = true
            endif
        })
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
export def Grep(grepCmd: string = null_string, ignorecase: bool = true)
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
            var cmd = (grepCmd ?? util.GrepCmd()) .. ' ' .. prompt .. ' ./'
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
                    var items_dict: list<dict<any>> = items->mapnew((_, v) => {
                        return {text: v, cmd: 'grep'}
                    })
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
            var frags = res.text->split()[0]->split(':')
            util.VisitFile(key, frags[0], frags[1])
        },
        (id, idp) => {
            win_execute(id, $"syn match ScopeMenuFilenameSubtle \".*:\\d\\+:\"")
            # note: it is expensive to regex match. even though following pattern
            #   is more accurate vim throws 'redrawtime exceeded' and stops
            # win_execute(menu.id, $"syn match FilterMenuMatch \"[^:]\\+:\\d\\+:\"")
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuFilenameSubtle ScopeMenuSubtle
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
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuDirectorySubtle ScopeMenuSubtle
        },
        util.FilterItems)
enddef

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
            try
                items_dict = GetItemsFn(prompt)->mapnew((_, v) => {
                    return {text: v}
                })
            catch
                echo 'Scope.vim exception' v:exception
                return
            endtry
            menu.SetText(items_dict,
                (_, _): list<any> => {
                return [items_dict, [items_dict]]
                }, 100)  # max 100 items
            var pat = prompt->escape('~')
            win_execute(menu.id, $"syn match ScopeMenuMatch \"\\c{pat}\"")
        endif
    enddef

    def ExecCmd(key: string, tag: string, t: number)
        if cmd == 'tag'
            try
                exe $"{cmd} {tag}"
            catch  # :tag command throws E1050 (vim bug)
            endtry
        else
            if key == "\<c-t>"
                exe $"tab {cmd} {tag}"
            elseif key == "\<c-v>"
                exe $"vert {cmd} {tag}"
            else
                exe $"{cmd} {tag}"
            endif
        endif
    enddef

    menu = popup.FilterMenu.new(title, [],
        (res, key) => {
            # when callback function is called in popup, the window and assciated buffer
            # are not yet deleted, and it is visible when ':tag' is called, which
            # opens a dialog split window. put this in a timer to let popup close.
            timer_start(1, function(ExecCmd, [key, res.text]))
        },
        null_function,
        (lst: list<dict<any>>, prompt: string): list<any> => {
            timer_start(1, function(DoCompletionItems, [menu.prompt]))
            return [[], [[]]]
        }, null_function, true)
enddef

export def Help()
    DoVimItems('Help', 'help', (p: string): list<string> => util.GetCompletionItems(p, 'help'))
enddef

export def Tag()
    DoVimItems('Tag', 'tag', (p: string): list<string> => util.GetCompletionItems(p, 'tag'))
enddef

export def Command()
    var cmds = getcompletion('', 'command')->mapnew((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Commands", cmds,
        (res, key) => {
            exe $":{res.text}"
        })
enddef
export def VimCommand()
    Command()
enddef

export def Keymap()
    var items = execute('map')->split("\n")->mapnew((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Keymap", items,
        (res, key) => {
            echo res.text
        })
enddef

export def MRU()
    var mru = []
    if has("win32")
        # windows is very slow checking if file exists
        # use non-filtered v:oldfiles
        mru = v:oldfiles
    else
        mru = v:oldfiles->copy()->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    endif
    mru->map((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("MRU", mru,
        (res, key) => {
            util.VisitFile(key, res.text)
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuDirectorySubtle ScopeMenuSubtle
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

var prev_bufsearch = null_string

export def BufSearch(word_under_cursor: bool = false, recall: bool = true)
    if prev_bufsearch == null_string || word_under_cursor
        prev_bufsearch = expand("<cword>")->trim()
    endif
    var lines = []
    for nr in range(1, line('$'))
        var line = getline(nr)
        lines->add({text: $"{line} ({nr})", line: line, linenr: nr})
    endfor
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new($'Search', lines,
        (res, key) => {
            if key == "\<C-q>"
                echo 'here'
            else
                exe $":{res.linenr}"
                if menu.prompt != null_string
                    var m = matchfuzzypos([res.line], menu.prompt)
                    if m[1]->len() > 0 && m[1][0]->len() > 0
                        setcharpos('.', [0, res.linenr, m[1][0][0] + 1])
                    endif
                endif
                normal! zz
                prev_bufsearch = menu.prompt
            endif
        },
        (winid, idp) => {
            win_execute(winid, 'syn match ScopeMenuLineNr "(\d\+)$"')
            hi def link ScopeMenuLineNr ScopeMenuSubtle
            hi def link ScopeMenuSubtle Comment
            if recall && prev_bufsearch != null_string
                idp->popup_settext($'{popup.options.promptchar} {prev_bufsearch}')
                idp->clearmatches()
                matchaddpos('ScopeMenuCursor', [[1, 3]], 10, -1, {window: idp})
                matchaddpos('ScopeMenuVirtualText', [[1, 4, 999]], 10, -1, {window: idp})
            endif
        },
        (lst: list<dict<any>>, ctx: string): list<any> => {
            if ctx->empty()
                return [lst, [lst]]
            else
                var filtered = lst->matchfuzzypos(ctx, {key: "line"})
                return [lst, filtered]
            endif
        }, null_function, true)
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
            util.VisitFile(key, $'{path_e}{res.text}')
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuDirectorySubtle ScopeMenuSubtle
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
            hi def link ScopeMenuHiLinksTo ScopeMenuSubtle
            hi def link ScopeMenuSubtle Comment
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
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuBraces ScopeMenuSubtle
            hi def link ScopeMenuCurrent Statement
        })
enddef

# both local and global marks displayed
export def Mark()
    var marks = 'marks'->execute()->split("\n")->slice(1)
    var marks_dict = marks->mapnew((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Mark (mark:line:col:file/text)", marks_dict,
        (res, key) => {
            var mark = (res.text)->matchstr('\v^\s*\zs\S+')
            if key == "\<c-t>"
                :tabe
            elseif key == "\<c-j>"
                :split
            elseif key == "\<c-v>"
                :vert split
            endif
            exe $"normal! '{mark}"
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuSubtle '^\\s*\\S\\+\\s*\\zs\\S\\+\\s\\+\\S\\+\\ze.*'")
            hi def link ScopeMenuSubtle Comment
        })
enddef

export def Register()
    var registers = 'registers'->execute()->split("\n")->slice(1)
    var registers_dict = registers->mapnew((_, v) => {
        return {text: v}
    })
    popup.FilterMenu.new("Register (Type:Name:Content)", registers_dict,
        (res, key) => {
            var reg = (res.text)->matchstr('\v^\s*\S+\s+\zs\S+')
            exe $'normal! {reg}p'
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuSubtle '^\\s*\\S\\+\\ze.*'")
            hi def link ScopeMenuSubtle Comment
        })
enddef

export def Option()
    var opts = getcompletion('', 'option')
    opts->filter((_, v) => exists($'&{v}'))
    var maxlen = opts->mapnew((_, v) => v->len())->max() + 2
    var options_dict = opts->mapnew((_, v) => {
        var optval = $'&{v}'->eval()
        return {text: printf($"%-{maxlen}s %s", v, optval), opt: v, val: optval}
    })
    popup.FilterMenu.new("Option", options_dict,
        (res, key) => {
            echo $':setlocal {res.opt}={res.val}'
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuSubtle '^\\s*\\S\\+\\zs.*'")
            hi def link ScopeMenuSubtle Comment
        },
        (lst: list<dict<any>>, ctx: string): list<any> => {
            if ctx->empty()
                return [lst, [lst]]
            else
                var filtered = lst->matchfuzzypos(ctx, {key: "opt"})
                return [lst, filtered]
            endif
        })
enddef

export def Autocmd()
    var aucmds = autocmd_get()
    var maxevtlen = aucmds->mapnew((_, v) => v->get('event', '')->len())->max()
    var aucmds_dict = aucmds->mapnew((_, v) => {
        var text = printf($"%-{maxevtlen}s %-15s %-20s %s",
            v->get('group', ''), v->get('event', ''), v->get('pattern', ''),
            v->get('cmd', ''))
        return {text: text, data: v}
    })
    popup.FilterMenu.new("Option", aucmds_dict,
        (res, key) => {
            var rd = res.data
            var lines = execute($"verbose au {rd->get('group', '')} {rd->get('event', '')} {rd->get('pattern', '')}")->split("\n")
            for line in lines
                var m = line->matchlist('\v\s*Last set from (.+) line (\d+)')
                if !m->empty() && m[1] != null_string && m[2] != null_string
                    util.VisitFile(key, m[1], str2nr(m[2]))
                    return
                endif
            endfor
            echom lines->slice(1)->join(' | ')
        })
enddef

# chunks of code shamelessly ripped from habamax
# https://github.com/habamax/.vim/blob/master/autoload/fuzzy.vim
