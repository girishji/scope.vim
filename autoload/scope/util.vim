vim9script

import './fuzzy.vim'

export def VisitFile(key: string, filename: string, lnum: number = -1)
    var cmd = {"\<C-j>": 'split', "\<C-v>": 'vert split', "\<C-t>": 'tabe'}
    if lnum > 0
        exe $":{cmd->get(key, 'e')} +{lnum} {filename}"
    else
        exe $":{cmd->get(key, 'e')} {filename}"
    endif
enddef

export def FilterItems(lst: list<dict<any>>, prompt: string, search_key: string = 'text', prioritize_files: bool = false): list<any>
    def PrioritizeFilename(matches: list<any>): list<any>
        # prioritize matched filenames over matched directory names
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
        var matches = lst->matchfuzzypos(pat, {key: search_key})
        if prioritize_files && !matches[0]->empty()
            return [lst, PrioritizeFilename(matches)]
        endif
        return [lst, matches]
    endif
enddef

export def FilterFilenames(lst: list<dict<any>>, prompt: string): list<any>
    return FilterItems(lst, prompt, 'text', true)
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

export def FindCmdExcludeDirs(): string
    # exclude dirs from .config/fd/ignore and .gitignore
    # var sep = has("win32") ? '\' : '/'
    # *nix only
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

export def GrepCmd(): string
    return 'grep --color=never -REIHins --exclude="*.git*" --exclude="*.swp" --exclude="*.zwc" --exclude-dir=plugged'
enddef

export def GetCompletionItems(s: string, type: string): list<string>
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

export def VisitDeclaration(key: string, cmd: string): bool
    var lines = execute(cmd)->split("\n")
    for line in lines
        var m = line->matchlist('\v\s*Last set from (.+) line (\d+)')
        if !m->empty() && m[1] != null_string && m[2] != null_string
            VisitFile(key, m[1], str2nr(m[2]))
            return true
        endif
    endfor
    return false
enddef

export def Escape4Highlight(s: string): string
    var pat = s->escape('~.[$^"')
    if pat[-1 : -1] == '\'
        pat = $'{pat}\'
    endif
    return pat
enddef

export def Send2Qickfix(key: string, unfiltered: list<dict<any>>, filtered: list<dict<any>>,
        title: string, MapFn: func(dict<any>): dict<any> = null_function): bool
    if ["\<C-q>", "\<C-Q>", "\<C-l>", "\<C-L>"]->index(key) == -1
        return false
    endif
    var lst = ["\<C-q>", "\<C-l>"]->index(key) != -1 ? filtered : unfiltered
    var qflist = ["\<C-q>", "\<C-Q>"]->index(key) != -1
    var SetXList = qflist ? function('setqflist') : function('setloclist', [0])
    if !lst->empty()
        var items = lst->mapnew((_, v) => {
            if MapFn == null_function
                return {text: v.text}
            else
                return MapFn(v)
            endif
        })
        if fuzzy.options.quickfix_stack
            SetXList([], ' ', {nr: '$', title: title, items: items})
        else
            SetXList([], 'r', {title: title, items: items})
        endif
        const evt: string = qflist ? 'clist' : 'llist'
        if exists($'#QuickFixCmdPost#{evt}')
            execute $'doautocmd <nomodeline> QuickFixCmdPost {evt}'
        endif
    endif
    return true
enddef
