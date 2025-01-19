vim9script

import './task.vim'
import './popup.vim'
import './util.vim'
import './lsp.vim'

export var options: dict<any> = {
    grep_echo_cmd: true,
    grep_throttle_len: 3,
    grep_skip_len: 0,
    grep_poll_interval: 20,
    timer_delay: 20,
    quickfix_stack: true,
    find_echo_cmd: false,
    mru_rel_path: false,
}

export def OptionsSet(option: dict<any>)
    options->extend(option)
enddef

export def FindCmd(dir: string = '.'): string
    return util.FindCmd($'{dir == null_string ? "." : dir}')
enddef

# fuzzy find files (build a list of files once and then fuzzy search on them)
# Note: specifying a directory to find files leads to unexpected results. if you
# specify 'find ~/.zsh ...' and you have '*/.*' pruned from -path, then it will
# not show anything since the whole path is matched, which includes .zsh.
export def File(findCmd: string = null_string, count: number = 100000, ignore_err: bool = true)
    var cmd = findCmd == null_string ? FindCmd() : findCmd
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("File", [],
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], cmd,
                    (v: dict<any>) => {
                        return {filename: v.text}
                    }) &&
                    !util.Send2Buflist(key, menu.filtered_items[0]->mapnew('v:val.text'))
                util.VisitFile(key, res.text)
            endif
            if options.find_echo_cmd
                util.EchoClear()
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuDirectorySubtle ScopeMenuSubtle
        },
        util.FilterFilenames,
        () => {
            if options.find_echo_cmd
                util.EchoClear()
            endif
        })

    if options.find_echo_cmd
        util.Echo(cmd)
    endif
    var job: task.AsyncCmd
    var workaround = false
    job = task.AsyncCmd.new(cmd,
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
            if !menu.SetText(items_dict, util.FilterFilenames, count)
                job.Stop()
            endif
            if !workaround
                feedkeys("\<bs>", "nt")  # workaround for https://github.com/vim/vim/issues/13932
                workaround = true
            endif
        },
        100, null_dict, ignore_err)
enddef

export def GrepCmd(flags: string = null_string): string
    return util.GrepCmd(flags)
enddef

var prev_grep = null_string

# live grep, not fuzzy search.
#
# `ignorecase` argument ensures case-insensitive text highlighting in the popup
# window. Incorporating colored `grep` output into Vim is a challenge. Instead
# of parsing color codes, Vim's syntax highlighting is used. As Vim lacks
# awareness of `grep`'s ignore-case flag, explicit instruction is needed for
# accurate highlighting.
export def Grep(grepCmd: string = null_string, ignorecase: bool = true,
        cword: string = null_string, dir: string = null_string)
    var menu: popup.FilterMenu
    var timer_delay = max([1, options.timer_delay])
    var grep_poll_interval = max([10, options.grep_poll_interval])
    var grep_throttle_len = max([0, options.grep_throttle_len])
    var grep_skip_len = max([0, options.grep_skip_len])
    var cmd: string
    var select_mode = false  # grep mode or select mode
    var cached_prompt = null_string

    def DoGrep(prompt: string, timer: number)
        # during pasting from clipboard to prompt window, spawning a new job for
        # every character input causes hiccups. return the control back to Vim's
        # main loop and let typehead catch up.
        if menu.prompt != prompt
            timer_start(timer_delay, function(DoGrep, [menu.prompt]))
            return
        endif
        prev_grep = prompt
        win_execute(menu.id, "syn clear ScopeMenuMatch")
        if options.grep_echo_cmd
            util.EchoClear()
        endif
        if prompt == null_string
            menu.SetText([])
        elseif prompt->len() > grep_skip_len
            # 'grep' requires some characters to be escaped (not tested for 'rg', 'ug', and 'ag')
            cmd = $'{grepCmd ?? GrepCmd()} {util.Escape(prompt)}'
            if has('win32') && grepCmd == null_string
                var dirstr = "*.*"
                if dir != null_string
                    if dir =~ '\\$'
                        dirstr = $'{dir}*'
                    elseif dir !~ '*$'
                        dirstr = $'{dir}\*'
                    endif
                endif
                cmd = $'powershell -command "findstr /s /i /n {util.Escape(prompt)} {dirstr}"'
            elseif grepCmd =~ 'rg\(\s\|$\)'
                cmd = $'{cmd} {dir != null_string ? dir : "./"}'
            elseif dir != null_string
                cmd = $'{cmd} {dir}'
            endif
            if options.grep_echo_cmd
                util.Echo(cmd)
            endif
            # do not convert cmd to list, as this will not quote space characters correctly.
            var job: task.AsyncCmd
            job = task.AsyncCmd.new(cmd,
                (items: list<string>) => {
                    if menu.prompt->len() <= grep_throttle_len || menu.Closed()
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
                }, grep_poll_interval)
            var pat = util.Escape4Highlight(prompt)
            try
                if ignorecase
                    win_execute(menu.id, $"syn match ScopeMenuMatch \"\\c{pat}\"")
                else
                    win_execute(menu.id, $"syn match ScopeMenuMatch \"{pat}\"")
                endif
            catch
                # ignore any rogue exceptions. all special chars have been escaped though.
            endtry
        endif
    enddef

    def SetPrompt(s: string, timer: number)
        menu.SetPrompt(s)
    enddef

    menu = popup.FilterMenu.new('Grep', [],
        (res, key) => {
            if key == "\<C-k>"
                select_mode = !select_mode
                if select_mode
                    cached_prompt = menu.prompt
                    menu.SetPrompt(null_string)
                    menu.SetText(menu.items_dict)
                else
                    timer_start(0, function(SetPrompt, [cached_prompt]))
                    timer_start(1, function(DoGrep, [cached_prompt]))
                endif
                return
            endif
            # let quicfix parse output of 'grep' for filename, line, column.
            # it deals with ':' in filename and other corner cases.
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], cmd, null_function, true)
                var flist = menu.filtered_items[0]->mapnew((_, v) => v.text->matchstr('\v^.{-}\ze:\d+:'))->uniq()
                if !util.Send2Buflist(key, flist)
                    var qfitem = getqflist({lines: [res.text]}).items[0]
                    if qfitem->has_key('bufnr')
                        util.VisitBuffer(key, qfitem.bufnr, qfitem.lnum, qfitem.col, qfitem.vcol > 0)
                        if !qfitem.bufnr->getbufvar('&buflisted')
                            # getqflist keeps buffer unlisted
                            setbufvar(qfitem.bufnr, '&buflisted', 1)
                        endif
                    else
                        echoerr 'Scope.vim: Incompatible:' res.text
                    endif
                endif
            endif
        },
        (id, idp) => {
            if select_mode
                return
            endif
            if cword != null_string
                var str: string = cword
                if str == '<cword>' || str == '<cWORD>'
                    str = expand(cword)
                endif
                timer_start(0, function(SetPrompt, [str]))
                timer_start(1, function(DoGrep, [str]))
            endif
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
            if select_mode
                if prompt->empty()
                    return [lst, [lst]]
                else
                    # pattern match only (not fuzzy match)
                    var filtered = []
                    if prompt[0] == '!'
                        filtered = lst->copy()->filter((_, v) => v.text !~ $'\v{prompt->slice(1)}')
                    else
                        for item in lst
                            var pos = item.text->matchstrpos(prompt)
                            if pos[1] != -1
                                filtered->add({text: item.text, props: [{col: pos[1] + 1, length: pos[2] - pos[1], type: 'ScopeMenuMatch'}]})
                            endif
                        endfor
                    endif
                    return [lst, [filtered]]
                endif
            else
                timer_start(timer_delay, function(DoGrep, [prompt]))
                return [[], [[]]]
            endif
        },
        () => {
            if options.grep_echo_cmd
                util.EchoClear()
            endif
        }, true)
enddef

export def Buffer(list_all_buffers: bool = false, goto_window: bool = true)
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Buffer", buffer_list,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Buffers',
                    (v: dict<any>) => {
                        return {bufnr: v.bufnr, text: v.text}
                    })
                if res.winid != -1 && goto_window
                    win_gotoid(res.winid)
                else
                    util.VisitBuffer(key, res.bufnr)
                endif
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuDirectorySubtle ScopeMenuSubtle
        },
        util.FilterFilenames)
enddef

export def DoVimItems(title: string, cmd: string, GetItemsFn: func(string): list<string>)
    var menu: popup.FilterMenu
    var timer_delay = options.timer_delay

    def DoCompletionItems(prompt: string, timer: number)
        if menu.prompt != prompt
            # to avoid hiccups when pasting from clipboard, return the control back to Vim's
            # main loop and let typehead catch up.
            timer_start(timer_delay, function(DoCompletionItems, [menu.prompt]))
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
            var pat = util.Escape4Highlight(prompt)
            try
                win_execute(menu.id, $"syn match ScopeMenuMatch \"\\c{pat}\"")
            catch
            endtry
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
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], title)
                # when callback function is called in popup, the window and associated buffer
                # are not yet deleted, and it is visible when ':tag' is called, which
                # opens a dialog split window. put this in a timer to let popup close.
                timer_start(timer_delay, function(ExecCmd, [key, res.text]))
            endif
        },
        null_function,
        (lst: list<dict<any>>, prompt: string): list<any> => {
            timer_start(timer_delay, function(DoCompletionItems, [menu.prompt]))
            return [[], [[]]]
        }, null_function, true)
enddef

export def Help()
    DoVimItems('Help', 'help', (p: string): list<string> => util.GetCompletionItems(p, 'help'))
enddef

export def Tag()
    # taglist() is much slower (does regex match)
    DoVimItems('Tag', 'tag', (p: string): list<string> => util.GetCompletionItems(p, 'tag'))
enddef

export def Command()
    var cmds = getcompletion('', 'command')->mapnew((_, v) => {
        return {text: v}
    })
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Commands", cmds,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Vim Commands')
                var cmd = $'verbose com {res.text}'
                if !util.VisitDeclaration(key, cmd)
                    echom res.text
                endif
            endif
        })
enddef
export def VimCommand()
    Command()
enddef

export def Keymap()
    var items = execute('map')->split("\n")->mapnew((_, v) => {
        return {text: v}
    })
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Keymap", items,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Keymap')
                var m = res.text->matchlist('\v^(\a)?\s+(\S+)')
                if m->len() > 2
                    var cmd = $'verbose {m[1]}map {m[2]}'
                    if !util.VisitDeclaration(key, cmd)
                        echom res.text
                    endif
                endif
            endif
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
    mru = mru->mapnew((_, v) => {
        return {text: options.mru_rel_path ? v->fnamemodify(':.') : v }
    })
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("MRU", mru,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'v:oldfiles',
                    (v: dict<any>) => {
                        return {filename: v.text}
                    }) &&
                    !util.Send2Buflist(key, menu.filtered_items[0]->mapnew((_, v) => v.text->fnamemodify(':p'))->uniq())
                util.VisitFile(key, res.text)
            endif
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
    popup.FilterMenu.new("Template", tmpls,
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

export def BufSearch(cword: string = null_string, recall: bool = true)
    if prev_bufsearch == null_string
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
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'BufSearch',
                    (v: dict<any>) => {
                        return {bufnr: bufnr(), lnum: v.linenr, text: v.line}
                    })
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
            if cword != null_string
                def SetPrompt(s: string, timer: number)
                    menu.SetPrompt(s)
                enddef
                def SetText(timer: number)
                    menu.SetText(menu.items_dict)
                enddef
                var str = expand(cword)
                if str != null_string
                    timer_start(0, function(SetPrompt, [str]))
                    timer_start(5, function(SetText))
                endif
            endif
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
            return util.FilterItems(lst, ctx, 'line')
        }, null_function, true)
enddef

export def GitFile(path: string = "")
    var path_e = path->empty() ? "" : $"{path}/"
    var git_cmd = 'git ls-files --other --full-name --cached --exclude-standard'
    var cd_cmd = path->empty() ? "" : $"cd {path} && "
    var git_files = systemlist($'{cd_cmd}{git_cmd}')->mapnew((_, v) => {
        return {text: v}
    })
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Git File", git_files,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'GitFile',
                    (v: dict<any>) => {
                        return {filename: $'{path_e}{v.text}'}
                    }) &&
                    !util.Send2Buflist(key, menu.filtered_items[0]->mapnew((_, v) => $'{path_e}{v.text}'))
                util.VisitFile(key, $'{path_e}{res.text}')
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuDirectorySubtle '^.*[\\/]'")
            hi def link ScopeMenuSubtle Comment
            hi def link ScopeMenuDirectorySubtle ScopeMenuSubtle
        })
enddef

export def Colorscheme()
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Colorscheme",
        getcompletion("", "color")->mapnew((_, v) => {
            return {text: v}
        }),
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Colorscheme')
                exe $":colorscheme {res.text}"
            endif
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Filetype", ft_list,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Filetype')
                exe $":set ft={res.text}"
            endif
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Highlight", hl,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Highlight')
                feedkeys($":{res.value}\<C-f>")
            endif
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Command History", cmd_history,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'CmdHistory')
                if key == "\<c-j>"
                    feedkeys($":{res.text}\<C-f>", "n")
                else
                    feedkeys($":{res.text}\<CR>", "nt")
                endif
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Mark (mark|line|col|file/text)", marks_dict,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Mark')
                var mark = (res.text)->matchstr('\v^\s*\zs\S+')
                if key == "\<c-t>"
                    :tabe
                elseif key == "\<c-j>"
                    :split
                elseif key == "\<c-v>"
                    :vert split
                endif
                exe $"normal! '{mark}"
            endif
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Register (Type|Name|Content)", registers_dict,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Register')
                var reg = (res.text)->matchstr('\v^\s*\S+\s+\zs\S+')
                exe $'normal! {reg}p'
            endif
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Option", options_dict,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Option')
                echo $':setlocal {res.opt}={res.val}'
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuSubtle '^\\s*\\S\\+\\zs.*'")
            hi def link ScopeMenuSubtle Comment
        },
        (lst: list<dict<any>>, ctx: string): list<any> => {
            return util.FilterItems(lst, ctx, 'opt')
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
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new("Option", aucmds_dict,
        (res, key) => {
            if !util.Send2Qickfix(key, menu.items_dict, menu.filtered_items[0], 'Autocmd')
                var rd = res.data
                var cmd = $"verbose au {rd->get('group', '')} {rd->get('event', '')} {rd->get('pattern', '')}"
                if !util.VisitDeclaration(key, cmd)
                    echom execute(cmd)->split("\n")->slice(1)->join(' | ')
                endif
            endif
        })
enddef

def XListHistory(qflist: bool = true)
    var XList = qflist ? function('getqflist') : function('getloclist', [0])
    const count: number = XList({nr: '$'}).nr
    if count == 0
        echo 'Current window has no error list'
        return
    endif
    const current: number = XList({nr: 0}).nr
    var items_dict = []
    for i in range(1, count)
        var title = XList({nr: i, title: 0}).title
        var err_count = XList({nr: i, size: 0}).size
        var cur = (i == current) ? '> ' : '  '
        items_dict->add({text: printf("%s%-5d %s", cur, err_count, title), index: i, title: title, size: err_count})
    endfor
    popup.FilterMenu.new($"{qflist ? 'Quickfix' : 'Loclist'} History (size|title)", items_dict,
        (res, key) => {
            const evt: string = qflist ? 'chistory' : 'lhistory'
            silent execute $':{res.index}{evt}'
            if exists($'#QuickFixCmdPost#{evt}')
                execute $'doautocmd <nomodeline> QuickFixCmdPost {evt}'
            endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuSubtle '^>\\?\\s\\+\\zs\\d\\+\\ze.*'")
            hi def link ScopeMenuSubtle Comment
        },
        (lst: list<dict<any>>, ctx: string): list<any> => {
            return util.FilterItems(lst, ctx, 'title')
        })
enddef

export def QuickfixHistory()
    XListHistory()
enddef

export def LoclistHistory()
    XListHistory(false)
enddef

def XListSearch(qflist: bool = true)
    var XList = qflist ? function('getqflist') : function('getloclist', [0])
    const count: number = XList({size: 1}).size
    if count == 0
        echo 'Error list is empty'
        return
    endif
    var cur_selected = XList({idx: 0}).idx
    var items_dict = XList()->mapnew((idx, v) => {
        var fname = null_string
        if v->has_key('filename')
            fname = v.filename
        elseif v->has_key('bufnr')
            fname = bufname(v.bufnr)
        endif
        var fmt = (idx + 1 == cur_selected ? "> %s" : "  %s")
        var vtext = v->get('text', '')
        var text: string
        var lnum = v->get('lnum', 0)
        if lnum > 0
            var col = v->get('col', 0)
            if col > 0
                text = printf($"{fmt}:%d:%d:%s", fname, lnum, col, vtext)
            else
                text = printf($"{fmt}:%d:%s", fname, lnum, vtext)
            endif
        else
            text = printf($"{fmt}:%s", fname, vtext)
        endif
        return {text: text, filename: fname, lnum: lnum, index: idx + 1, data: v}
    })

    popup.FilterMenu.new($"{qflist ? 'Quickfix' : 'Loclist'} (file:line:text)", items_dict,
        (res, key) => {
            const cmd: string = qflist ? 'cc!' : 'll!'
            silent execute $':{cmd} {res.index}'
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuSubtle '\\zs\\(:\\d\\+\\)\\{0,2}:\\ze.*'")
            hi def link ScopeMenuSubtle Comment
        })
enddef

export def Quickfix()
    XListSearch()
enddef

export def Loclist()
    XListSearch(false)
enddef

export def LspDocumentSymbol()
    lsp.DocumentSymbol()
enddef

export def Jumplist()
    var jumps = execute("jumps")->split("\n")[1 : ]
    var curr_idx = jumps->match('\v^\s*\>')

    popup.FilterMenu.new("Jumplist (jump|line|col|file/text)", jumps->mapnew((_, v) => ({text: v})),
        (res, key) => {
              var idx = jumps->index(res.text)
              var delta = curr_idx - idx
              if delta > 0
                  exe $"normal! {delta}\<C-o>"
              else
                  exe $"normal! {abs(delta)}\<C-i>"
              endif
        },
        (winid, _) => {
            win_execute(winid, "syn match ScopeMenuSubtle '\\s\\+\\d\\+\\s\\+\\d\\+\\s\\+\\d\\+\\s\\+'")
            hi def link ScopeMenuSubtle Comment
        },
    )
enddef

export def HelpfilesGrep()
    var cmd = 'grep --color=never -REIHins --include="*.txt"'
    var dirs = &rtp->split(',')->mapnew((_, v) => $'{v}/doc')->filter((_, v) => v->isdirectory())
    Grep(cmd, true, null_string, dirs->join(' '))
enddef

# chunks of code shamelessly ripped from habamax
# https://github.com/habamax/.vim/blob/master/autoload/fuzzy.vim
