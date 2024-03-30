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

export def VisitBuffer(key: string, bufnr: number, lnum: number = -1, col: number = -1, visualcol: bool = false)
    var cmd = {"\<C-j>": 'sb', "\<C-v>": 'vert sb', "\<C-t>": 'tab sb'}
    var cmdstr = cmd->get(key, 'b')
    if lnum > 0
        if col > 0
            var pos = visualcol ? 'setcharpos' : 'setpos'
            cmdstr = $'{cmdstr} +call\ {pos}(".",\ [0,\ {lnum},\ {col},\ 0])'
        else
            cmdstr = $'{cmdstr} +{lnum}'
        endif
    endif
    exe $":{cmdstr} {bufnr}"
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

export def FindCmd(gitignore: bool = true): string
    var [dirs, basenames, relpaths] = [['.*'], ['.*', '*.swp'], []]
    var cmd = 'find .'
    if gitignore
        var lines = []
        for ignored in [getenv('HOME') .. '/.gitignore', '.gitignore']
            if ignored->filereadable()
                lines->extend(readfile(ignored)->filter((_, v) => v != '' && v !~ '^#'))
            endif
        endfor
        for item in lines
            var idx = item->strridx('/')
            if idx == -1
                basenames->add(item) 
            elseif idx == item->len() - 1
                dirs->add(item)
            else
                relpaths->add(item)
            endif
        endfor
    endif
    var paths = Unique(dirs)->mapnew((_, v) => $'-path "*/{v}"') + Unique(relpaths)->mapnew((_, v) => $'-path "./{v}"')
    cmd ..= ' ( ' .. paths->join(' -o ') .. ' ) -prune -o'
    cmd ..= ' -not ( ' .. Unique(basenames)->mapnew((_, v) => $'-name "{v}"')->join(' -o ') .. ' )'
    return cmd .. ' -type f -print -follow'
enddef

def Unique(lst: list<string>): list<string>
    var found = {}
    var res = []
    for l in lst
        if !found->has_key(l)
            found[l] = true
            res->add(l)
        endif
    endfor
    return res
enddef

export def GrepCmd(): string
    # default shell does not support gnu '{' expansion (--option={x,y})
    return 'grep --color=never -REIHins --exclude-dir="*.git*" --exclude="*.swp" --exclude="*.zwc"'
enddef

export def Escape(s: string): string
    var escaped = s->substitute('\\', '\\\\\\\', 'g')
    escaped = escaped->substitute('\[', '\\\\\\[', 'g')
    escaped = escaped->substitute('\([ "]\)', '\\\1', 'g')
    escaped = escaped->substitute('\([?(*$^.+|-]\)', '\\\\\1', 'g')
    return escaped
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
        title: string, MapFn: func(dict<any>): dict<any> = null_function, formatted: bool = false): bool
    if ["\<C-q>", "\<C-Q>", "\<C-l>", "\<C-L>"]->index(key) == -1
        return false
    endif
    var lst = ["\<C-q>", "\<C-l>"]->index(key) != -1 ? filtered : unfiltered
    var qflist = ["\<C-q>", "\<C-Q>"]->index(key) != -1
    var SetXList = qflist ? function('setqflist') : function('setloclist', [0])
    var qf_stack = fuzzy.options.quickfix_stack
    var action = qf_stack ? ' ' : 'r'
    var what: dict<any> = qf_stack ? {nr: '$', title: title} : {title: title}
    if !lst->empty()
        if MapFn == null_function
            if formatted
                var lines = lst->mapnew((_, v) => v.text)
                SetXList([], action, what->extend({lines: lines}))
            else
                var items = lst->mapnew((_, v) => {
                    return {text: v.text}
                })
                SetXList([], action, what->extend({items: items}))
            endif
        else
            var items = lst->mapnew((_, v) => MapFn(v))
            SetXList([], action, what->extend({items: items}))
        endif
        const evt: string = qflist ? 'clist' : 'llist'
        if exists($'#QuickFixCmdPost#{evt}')
            execute $'doautocmd <nomodeline> QuickFixCmdPost {evt}'
        endif
    endif
    return true
enddef

var saved_cmdheight: number

export def Echo(s: string)
    var maxlen = &columns - 12
    if s->len() < maxlen
        :echo s
        saved_cmdheight = -1
    else
        var lcount = (s->len() / maxlen) + 1
        saved_cmdheight = &cmdheight
        :exec $'setl cmdheight={lcount}'
        var lines = []
        for i in range(lcount)
            lines->add(s->slice(i * maxlen, (i + 1) * maxlen))
        endfor
        echo lines->join("\n")
    endif
enddef

export def EchoClear()
    if saved_cmdheight > 0
        :exec $'setl cmdheight={saved_cmdheight}'
    endif
    :echo ''
enddef
