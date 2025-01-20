vim9script

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

# Ignores patterns from .gitignore and 'wildignore'.
#
export def FindCmd(dir: string = '.'): string
    if has('win32')
        return 'powershell -command "gci . -r -n -File"'
    endif
    var cmd: string = $'find {dir}'
    var patterns = [".git/*"]
    for ignored in [$'{$HOME}/.gitignore', $'{$HOME}/.findignore', $'{dir}/.gitignore', $'{dir}/.findignore']
        if ignored->filereadable()
            patterns->extend(readfile(ignored)->filter((_, v) => v !~ '^\s*$\|^\s*#'))
        endif
    endfor
    var paths = Unique(patterns)->mapnew((_, v) => {
        if v->stridx('**') != -1 || v->stridx('!') != -1
            # cannot support these patterns--slows down 'find' command
            # See PATTERN FORMAT under https://git-scm.com/docs/gitignore
            return ''  # filter out these empty strings later when joining
        endif
        var idx = v->stridx('/')
        if idx != -1 && idx != v->len() - 1  # relative path
            var pat = (v[-1] == '/') ? v[0 : -2] : v
            return (pat[0] == '*') ? $'-path "{pat}"' : $'-path "{dir}/{pat}"'
        else  # exclude these wherever they appear in the path
            var pat = (v[-1] == '/') ? v[0 : -2] : v
            return $'-path "*/{pat}"'
        endif
    })
    # wildignore (:h autocmd-patterns)
    var fnames = []
    for pat in &wildignore->split(',')
        if pat->stridx('/') != -1
            paths->add((pat[0] == '*') ? $'-path "{pat}"' : $'-path "{dir}/{pat}"')
        else
            fnames->add($'-name "{pat}"')
        endif
    endfor
    paths->filter((_, v) => v != null_string)
    if !paths->empty()
        cmd ..= ' ( ' .. paths->join(' -o ') .. ' ) -prune -o'
    endif
    if !fnames->empty()
        cmd ..= ' ' .. fnames->join(' -o ') .. ' -o'
    endif
    cmd ..= ' -type f -follow -print'
    return cmd
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

export def GrepCmd(flags: string = null_string): string
    if has('win32')
        return ''
    endif
    # default shell does not support gnu '{' expansion (--option={x,y})
    var macos = has('macunix')
    var gflags = (flags == null_string) ? (macos ? '-REIHSins' : '-REIHins') : flags
    var cmd = $'grep --color=never {gflags}'
    # wildignore (:h autocmd-patterns)
    var excl = &wildignore->split(',')->mapnew((_, v) => {
        if v->stridx('/') != -1
            if macos
                # BSD grep expects full path for exclude-dir as it appears in grep output (which begins with a './')
                return (v[0 : 1] == './' || v[0] == '*') ? $'--exclude-dir="{v}"' : $'--exclude-dir="./{v}"'
            else
                # linux expects a glob pattern without trailing '*' and leading '*/' for exclude-dir
                return '--exclude-dir="' .. v->substitute('^\**/\{0,1}\(.\{-}\)/\{0,1}\**$', '\1', '') .. '"'
            endif
        else
            return $'--exclude="{v}"'
        endif
    })
    cmd ..= ' ' .. excl->join(' ')
    if &wildignore !~ '\(^\|,\)\.git[/,]'
        cmd ..= ' ' .. (macos ? '--exclude="./.git/*"' : '--exclude-dir=".git"')
    endif
    return cmd
enddef

export def Escape(s: string): string
    if &shellxquote == '('  # for windows, see ':h sxq'
        return s->substitute('\([' .. &shellxescape .. ']\)', '^\1', 'g')
    else
        var escaped = s->substitute('\\', '\\\\\\\', 'g')
        escaped = escaped->substitute('\[', '\\\\\\[', 'g')
        escaped = escaped->substitute('\([ "]\)', '\\\1', 'g')
        escaped = escaped->substitute('\([?()*$^.+|-]\)', '\\\\\1', 'g')
        return escaped
    endif
enddef

export def GetCompletionItems(s: string, type: string): list<string>
    var saved_wo = &wildoptions
    var items: list<string> = []
    try
        :set wildoptions=fuzzy
        items = getcompletion(s, type)
    finally
        exe $'set wildoptions={saved_wo}'
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
    var qf_stack = fuzzy#options.quickfix_stack
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

export def Send2Buflist(key: string, flist: list<string>): bool
    if key == "\<C-o>"  # send filtered files to buffer list
        for str in flist
            setbufvar(bufadd(str), "&buflisted", true)
        endfor
    elseif key == "\<C-g>"  # send filtered files to argument list
        execute($'argadd {flist->join(" ")}')
    else
        return false
    endif
    return true
enddef

var saved = { cmdheight: -1, scrolloff: -1, toplinenr: -1 }

export def Echo(s: string)
    var maxlen = &columns - 12
    if s->len() < maxlen
        :echo s
        saved.cmdheight = -1
    else
        var lcount = (s->len() / maxlen) + 1
        saved.cmdheight = &l:cmdheight
        # To prevent viewport from shifting up, temporarily move the cursor
        saved.scrolloff = &l:scrolloff  # -1 if this local var is not set. global var defaults to 0
        saved.toplinenr = line('w0')
        var saved_cursor = getcurpos()[1 : 2]
        if line('w$') - line('.') > lcount
            :setlocal scrolloff=0
            cursor(line('w0'), 1)
        endif
        :exec $'setlocal cmdheight={lcount}'
        var lines = []
        for i in range(lcount)
            lines->add(s->slice(i * maxlen, (i + 1) * maxlen))
        endfor
        echo lines->join("\n")
        cursor(saved_cursor[0], saved_cursor[1])
    endif
enddef

export def EchoClear()
    :echo ''
    if saved.cmdheight > 0
        var saved_cursor = getcurpos()[1 : 2]
        :exec $'setlocal cmdheight={saved.cmdheight}'
        :setlocal scrolloff=0
        cursor(saved.toplinenr, 1)
        :normal zt
        cursor(saved_cursor[0], saved_cursor[1])
        :exec $'setlocal scrolloff={saved.scrolloff}'
        saved.cmdheight = -1
    endif
enddef
