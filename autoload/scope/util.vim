vim9script

export def VisitFile(key: string, filename: string, lnum: number = -1)
    var cmd = {"\<C-j>": 'split', "\<C-v>": 'vert split', "\<C-t>": 'tabe'}
    if lnum > 0
        exe $":{cmd->get(key, 'e')} +{lnum} {filename}"
    else
        exe $":{cmd->get(key, 'e')} {filename}"
    endif
enddef

export def FilterItems(lst: list<dict<any>>, prompt: string): list<any>
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
        var matches = lst->matchfuzzypos(pat, {key: "text"})
        if matches[0]->empty() || pat =~ '\s'
            return [lst, matches]
        else
            return [lst, PrioritizeFilename(matches)]
        endif
    endif
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
    return 'grep --color=never -RESIHin --exclude="*.git*" --exclude="*.swp" --exclude="*.zwc" --exclude-dir=plugged'
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
