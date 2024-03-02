vim9script

import './popup.vim'
import './task.vim'

def FilterItems(lst: list<dict<any>>, prompt: string): list<any>
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

def FindCmdExcludeDirs(): string
    # exclude dirs from .config/fd/ignore and .gitignore
    var excludes = []
    var ignore_files = [getenv('HOME') .. '/.config/fd/ignore', '.gitignore']
    for ignore in ignore_files
        if ignore->filereadable()
            excludes->extend(readfile(ignore)->filter((_, v) => v != '' && v !~ '^#'))
        endif
    endfor
    var exclcmds = []
    for item in excludes
        var idx = item->strridx(sep)
        if idx == item->len() - 1
            exclcmds->add($'-type d -path */{item}* -prune')
        else
            exclcmds->add($'-path */{item}/* -prune')
        endif
    endfor
    var cmd = 'find . ' .. (exclcmds->empty() ? '' : exclcmds->join(' -o '))
    return cmd .. ' -o -name *.swp -prune -o -path */.* -prune -o -type f -print -follow'
enddef

def FindCmd(): list<any>
    var sep = has("win32") ? '\' : '/'
    if executable('fd')
        return 'fd -tf --follow'->split()
    else
        var cmd = ['find', '.']
        for fname in ['*.zwc', '*.swp']
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
    var menu = popup.FilterMenu.new("File", [],
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
        (winid) => {
            win_execute(winid, "syn match FilterMenuDirectorySubtle '^.*[\\/]'")
            hi def link FilterMenuDirectorySubtle Comment
        },
        FilterItems)

    var job: task.AsyncCmd
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
        })
enddef

# live grep, not fuzzy search. for space use '\ '.
# cannot use >1 words unless spaces are escaped (grep pattern
#   is: grep <pat> <path1, path2, ...>, so it will interpret second word as path)
export def Grep(grepcmd: string = '')
    var menu: popup.FilterMenu
    menu = popup.FilterMenu.new('Grep', [],
        (res, key) => {
            # callback
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
        null_function,
        (lst: list<dict<any>>, prompt: string): list<any> => {
            # This is called everytime when user types something
            win_execute(menu.id, "syn clear")
            echo ''
            if prompt != null_string
                var cmd = (grepcmd ?? &grepprg) .. ' ' .. prompt
                echo cmd
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
                win_execute(menu.id, $"syn match FilterMenuMatch \"{menu.prompt->escape('~ \')}\"")
            endif
            return [lst, [lst]]
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
        (winid) => {
            win_execute(winid, "syn match FilterMenuDirectorySubtle '^.*[\\/]'")
            hi def link FilterMenuDirectorySubtle Comment
        },
        FilterItems)
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
        (winid) => {
            win_execute(winid, "syn match FilterMenuDirectorySubtle '^.*[\\/]'")
            hi def link FilterMenuDirectorySubtle Comment
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
        (winid) => {
            win_execute(winid, 'syn match FilterMenuLineNr "(\d\+)$"')
            hi def link FilterMenuLineNr Comment
        })
enddef
