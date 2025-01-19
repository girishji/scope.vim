vim9script

export var options = {
    borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    bordercharsp: ['─', '│', '═', '│', '┌', '┐', '╡', '╞'],
    borderhighlight: ['Normal'],
    highlight: 'Normal',
    scrollbarhighlight: 'PmenuSbar',
    thumbhighlight: 'PmenuThumb',
    drag: 0,
    wrap: 0,
    padding: [0, 1, 0, 1],
    maxheight: -1,
    maxwidth: -1,
    promptchar: '>',
    # cursorchar: '█',
    emacsKeys: false,
}

export def OptionsSet(opt: dict<any>)
    options->extend(opt)
enddef

var history: dict<list<string>> = {}

export class FilterMenu

    var prompt: string = ''
    var id: number
    var idp: number  # id of prompt window
    var title: string
    var items_dict: list<dict<any>>
    var filtered_items: list<any>
    var minwidth: number
    var maxwidth: number
    var maximize: bool
    var cursorpos: number = 3  # based on character index, not byte index
    var history_idx: number

    def SetPrompt(s: string)
        this.prompt = s
        this.cursorpos = 3 + s->strcharlen()
    enddef

    def _CommonProps(borderchars: list<string>, top_pos: number, winheight: number): dict<any>
        return {
            line: top_pos,
            minwidth: this.minwidth,
            maxwidth: this.maxwidth,
            minheight: winheight,
            maxheight: winheight,
            border: [],
            borderchars: borderchars,
            borderhighlight: options.borderhighlight,
            highlight: options.highlight,
            scrollbarhighlight: options.scrollbarhighlight,
            thumbhighlight: options.thumbhighlight,
            drag: options.drag,
            wrap: options.wrap,
            cursorline: false,
            padding: options.padding,
            mapping: 0,
            hidden: !this.maximize,
        }->extend(this.maximize ? {col: (&columns - this.maxwidth) / 2 - 1} : {})
    enddef

    def _SetPopupContent()
        var items_count = this.items_dict->len()
        var titletxt = $" ({items_count > 0 ? this.filtered_items[0]->len() : 0}/{items_count}) {this.title} "
        this.idp->popup_setoptions({title: titletxt})
        if this.filtered_items[0]->empty()
            win_execute(this.id, "setl nonu nocursorline")
        else
            win_execute(this.id, "setl nu cursorline")
            win_execute(this.id, "normal! gg")
        endif
        this.id->popup_settext(this._Printify(this.filtered_items))
        # this.idp->popup_settext($'{options.promptchar} {this.prompt}{options.cursorchar}')
        this.idp->popup_settext($'{options.promptchar} {this.prompt} ')
        this._CursorSet()

        var pos = this.id->popup_getpos()
        var new_width = pos.core_width
        if new_width > this.minwidth
            this.minwidth = new_width
            popup_move(this.id, {minwidth: this.minwidth})
            var widthp = this.minwidth + (pos.scrollbar ? 1 : 0)
            popup_move(this.idp, {minwidth: widthp, maxwidth: widthp, col: pos.col})
        else
            var widthp = new_width + (pos.scrollbar ? 1 : 0)
            popup_move(this.idp, {minwidth: widthp, maxwidth: widthp, col: pos.col})
        endif
    enddef

    def new(title: string, items_dict: list<dict<any>>, Callback: func(any, string), Setup: func(number, number) = null_function, GetFilteredItems: func(list<any>, string): list<any> = null_function, Cleanup: func() = null_function, maximize: bool = false)
        if empty(prop_type_get('ScopeMenuMatch'))
            :highlight default link ScopeMenuMatch Special
            prop_type_add('ScopeMenuMatch', {highlight: "ScopeMenuMatch", override: true, priority: 1000, combine: true})
        endif
        if hlget('ScopeMenuCursor')->empty()
            :highlight default ScopeMenuCursor term=reverse cterm=reverse gui=reverse
        endif
        if hlget('ScopeMenuVirtualText')->empty()
            :highlight default link ScopeMenuVirtualText Comment
        endif
        this.title = title
        this.items_dict = items_dict
        this.maximize = maximize
        var items_count = this.items_dict->len()
        var [height, pos_top] = this._GetHeight(items_count)
        [this.minwidth, this.maxwidth] = this._GetWidth()
        this.history_idx = -1
        var ignore_input = ["\<cursorhold>", "\<ignore>", "\<Nul>",
                    \ "\<LeftMouse>", "\<LeftRelease>", "\<LeftDrag>", $"\<2-LeftMouse>",
                    \ "\<RightMouse>", "\<RightRelease>", "\<RightDrag>", "\<2-RightMouse>",
                    \ "\<MiddleMouse>", "\<MiddleRelease>", "\<MiddleDrag>", "\<2-MiddleMouse>",
                    \ "\<MiddleMouse>", "\<MiddleRelease>", "\<MiddleDrag>", "\<2-MiddleMouse>",
                    \ "\<X1Mouse>", "\<X1Release>", "\<X1Drag>", "\<X2Mouse>", "\<X2Release>", "\<X2Drag>",
                    \ "\<ScrollWheelLeft>", "\<ScrollWheelRight>"
        ]
        var ignore_input_utf8 = [
            # this sequence of bytes are generated when left/right mouse is
            # pressed and mouse wheel is rolled
            [128, 253, 100],
            # In xterm, when bracketed paste mode is set, the program will receive: ESC [ 200 ~,
            # followed by the pasted text, followed by ESC [ 201 ~.
            [128, 80, 83],
            [128, 80, 69],
        ]
        var ctrl_r_active = false

        this.idp = popup_create([$'{options.promptchar}  '],
            this._CommonProps(options.bordercharsp, pos_top, 1)->extend({
            title: $" ({items_count}/{items_count}) {this.title} ",
            }))
        this._CursorSet()

        this.id = popup_create([],
            this._CommonProps(options.borderchars, pos_top + 3, height)->extend({
                border: [0, 1, 1, 1],
                filter: (id, key) => {
                    if key == "\<C-r>"
                        ctrl_r_active = true
                    elseif ["\<C-w>", "\<C-a>", "\<C-l>"]->index(key) == -1 && key !~ '\p'
                        ctrl_r_active = false
                    endif
                    items_count = this.items_dict->len()
                    if key == "\<esc>"
                        this.idp->popup_close(-1)
                        id->popup_close(-1)
                        if Cleanup != null_function
                            Cleanup()
                        endif
                    elseif ["\<cr>", "\<C-j>", "\<C-v>", "\<C-t>", "\<C-o>", "\<C-g>", "\<C-Q>"]->index(key) > -1 ||
                            (!ctrl_r_active && key == "\<C-L>")  # <C-L> matches both <C-L> and <C-l>
                        this.idp->popup_close(-1)
                        if this.filtered_items[0]->len() > 0 && items_count > 0
                            id->popup_close({idx: getcurpos(id)[1], key: key})
                        else
                            # close the popup window for <cr> when popup window is empty
                            id->popup_close(-1)
                        endif
                    elseif key == "\<Right>" || key == "\<PageDown>" || (options.emacsKeys && key == "\<C-f>")
                        if this.idp->getmatches()->indexof((_, v) => v.group == 'ScopeMenuVirtualText') != -1
                            # virtual text present. grep using virtual text.
                            this.prompt = this.idp->getwininfo()[0].bufnr->getbufline(1)[0]->slice(2)
                            this.cursorpos = this.cursorpos + this.prompt->strcharlen()
                            var GetFilteredItemsFn = GetFilteredItems == null_function ? this._GetFilteredItems : GetFilteredItems
                            [this.items_dict, this.filtered_items] = GetFilteredItemsFn(this.items_dict, this.prompt)
                            this._SetPopupContent()
                        else
                            if key == "\<Right>" || (options.emacsKeys && key == "\<C-f>")
                                if this.cursorpos < (3 + this.prompt->strcharlen())
                                    this.cursorpos = this.cursorpos + 1
                                    this._CursorSet()
                                endif
                            else
                                win_execute(id, 'normal! ' .. "\<C-d>")
                            endif
                        endif
                    elseif key == "\<Left>" || (options.emacsKeys && key == "\<C-b>")
                        if this.cursorpos > 3
                            this.cursorpos = this.cursorpos - 1
                            this._CursorSet()
                        endif
                    elseif key == "\<C-Right>" || key == "\<S-Right>" || (options.emacsKeys && key == "\<A-f>")
                        if this.cursorpos < (3 + this.prompt->strcharlen())
                            var pos = this.cursorpos - 3
                            var byteidx = this.prompt->stridx(' ', this.prompt->byteidx(pos) + 1)
                            if byteidx != -1
                                this.cursorpos = 3 + this.prompt->charidx(byteidx)
                            else
                                this.cursorpos = 3 + this.prompt->strcharlen()
                            endif
                            this._CursorSet()
                        endif
                    elseif key == "\<C-Left>" || key == "\<S-Left>" || (options.emacsKeys && key == "\<A-b>")
                        if this.cursorpos > 3
                            var pos = this.cursorpos - 3
                            if pos > 1 && this.prompt[pos - 1] == ' ' && this.prompt[pos - 2] == ' '
                                this.cursorpos = this.cursorpos - 1
                            else
                                var left = this.prompt->slice(0, pos)->matchstr('.*\s\+\ze\k\+\s*$')
                                this.cursorpos = 3 + left->strcharlen()
                            endif
                            this._CursorSet()
                        endif
                    elseif key == "\<PageUp>"
                        win_execute(id, 'normal! ' .. "\<C-u>")
                    elseif key == "\<Home>" || (!options.emacsKeys && key == "\<C-b>") || (options.emacsKeys && key == "\<C-a>")
                        if this.cursorpos > 3
                            this.cursorpos = 3
                            this._CursorSet()
                        endif
                    elseif key == "\<End>" || key == "\<C-e>"
                        if this.cursorpos < (3 + this.prompt->strcharlen())
                            this.cursorpos = 3 + this.prompt->strcharlen()
                            this._CursorSet()
                        endif
                    elseif ["\<tab>", "\<C-n>", "\<Down>", "\<ScrollWheelDown>"]->index(key) > -1
                        var ln = getcurpos(id)[1]
                        win_execute(id, "normal! j")
                        if ln == getcurpos(id)[1]
                            win_execute(id, "normal! gg")
                        endif
                    elseif ["\<S-tab>", "\<C-p>", "\<Up>", "\<ScrollWheelUp>"]->index(key) > -1
                        var ln = getcurpos(id)[1]
                        win_execute(id, "normal! k")
                        if ln == getcurpos(id)[1]
                            win_execute(id, "normal! G")
                        endif
                    elseif ignore_input->index(key) == -1 &&
                            # ignoring double clicks, which are 6 char long: `<80><fc> <80><fd>.`
                            strchars(key) != 6 &&
                            ignore_input_utf8->index(str2list(key)) == -1
                        if ["\<S-Up>", "\<S-Down>", "\<C-Up>", "\<C-Down>"]->index(key) > -1
                            if history->has_key(this.title)
                                var listlen = history[this.title]->len()
                                if key == "\<C-Up>" || key == "\<S-Up>"
                                    this.history_idx = (this.history_idx > 0) ? this.history_idx - 1 : listlen - 1
                                else
                                    this.history_idx = (this.history_idx < 0 || this.history_idx > (listlen - 2)) ?
                                        0 : this.history_idx + 1
                                endif
                                this.prompt = history[this.title][this.history_idx]
                                this.cursorpos = 3 + this.prompt->strcharlen()
                            endif
                        elseif key == "\<C-U>"
                            if this.prompt == null_string
                                return true
                            endif
                            this.prompt = null_string
                            this.cursorpos = 3
                        elseif !ctrl_r_active && key == "\<C-w>"
                            if this.prompt == null_string
                                return true
                            endif
                            if this.prompt->stridx(' ') == -1
                                this.prompt = null_string
                                this.cursorpos = 3
                            else
                                var pos = this.cursorpos - 3
                                var right = this.prompt->slice(pos)
                                this.prompt = this.prompt->slice(0, pos)->matchstr('.*\s\+\ze\k\+\s*$')
                                this.cursorpos = 3 + this.prompt->strcharlen()
                                this.prompt = this.prompt .. right
                            endif
                        elseif key == "\<C-h>" || key == "\<bs>"
                            if this.prompt == null_string
                                return true
                            endif
                            this.cursorpos = this.cursorpos - 1
                            var pos = this.cursorpos - 3
                            this.prompt = this.prompt->slice(0, pos) .. this.prompt->slice(pos + 1)
                        elseif ctrl_r_active && ["\<C-w>", "\<C-a>", "\<C-l>"]->index(key) > -1
                            if key == "\<C-l>"
                                this.prompt = getline('.')->trim()
                                this.cursorpos = 3 + this.prompt->strcharlen()
                            else
                                # vim bug: ..= and += are not working (https://github.com/vim/vim/issues/14236)
                                var cword = (key == "\<C-w>") ? expand("<cword>")->trim() : expand("<cWORD>")->trim()
                                this.prompt = this.prompt .. cword
                                this.cursorpos = this.cursorpos + cword->strcharlen()
                            endif
                            ctrl_r_active = false
                        elseif key =~ '\p'
                            if ctrl_r_active
                                this.prompt = key->slice(1)->getreg()->trim()
                                this.cursorpos = 3 + this.prompt->strcharlen()
                                ctrl_r_active = false
                            else
                                var pos = this.cursorpos - 3
                                if key == "P" && has('gui') && (this.prompt->slice(0, pos) =~# '"+g$')  # issue 32
                                    var pasted = getreg('+')
                                    this.prompt = this.prompt->slice(0, pos - 3) .. pasted .. this.prompt->slice(pos)
                                    this.cursorpos = this.cursorpos - 3 + pasted->len()
                                else
                                    this.prompt = this.prompt->slice(0, pos) .. key .. this.prompt->slice(pos)
                                    this.cursorpos = this.cursorpos + key->len()
                                endif
                            endif
                        elseif key == "\<C-k>"
                            Callback(null_string, key)
                            return true
                        endif
                        var GetFilteredItemsFn = GetFilteredItems == null_function ? this._GetFilteredItems : GetFilteredItems
                        [this.items_dict, this.filtered_items] = GetFilteredItemsFn(this.items_dict, this.prompt)
                        this._SetPopupContent()
                    endif
                    return true
                },
                callback: (id, result) => {
                    this.idp->popup_close(-1)  # when <c-c> is pressed explicitly close the second popup
                    if this.prompt != null_string
                        if !history->has_key(this.title)
                            history[this.title] = []
                        endif
                        history[this.title]->add(this.prompt)
                    endif
                    if result->type() == v:t_dict
                        Callback(this.filtered_items[0][result.idx - 1], result.key)
                    endif
                }
        }))
        win_execute(this.id, "setl nu cursorline cursorlineopt=both")
        this.SetText(this.items_dict)
        if Setup != null_function
            Setup(this.id, this.idp)
        endif
    enddef

    def Closed(): bool
        return this.id->popup_getpos()->empty()
    enddef

    def _GetHeight(items_count: number): list<number>
        var height = &lines - &cmdheight - 6
        if options.maxheight > 0
            height = min([options.maxheight, max([height, 5])])
        elseif !this.maximize
            height = min([height, max([items_count, 5])])
        endif
        var pos_top = ((&lines - height) / 2) - 1
        return [height, pos_top]
    enddef

    def _GetWidth(): list<number>
        var minwidth = (&columns * 0.6)->float2nr()
        var maxwidth = (&columns - 14)
        if options.maxwidth != -1
            # make sure we fit into the screen
            maxwidth = min([options.maxwidth, &columns - 8])
        endif
        if this.maximize
            minwidth = maxwidth
        endif
        return [minwidth, maxwidth]
    enddef

    def SetText(items_dict: list<dict<any>>, GetFilteredItems: func(list<any>, string): list<any> = null_function, max_items: number = -1): bool
        if this.Closed()
            return false
        endif
        var GetItemsFn = GetFilteredItems == null_function ? this._GetFilteredItems : GetFilteredItems
        [this.items_dict, this.filtered_items] = GetItemsFn(items_dict, this.prompt)
        var items_count = this.items_dict->len()
        var [height, pos_top] = this._GetHeight(items_count)
        popup_setoptions(this.id, {minheight: height, maxheight: height, line: pos_top + 3})
        popup_setoptions(this.idp, {line: pos_top})
        this._SetPopupContent()
        if !this.id->popup_getpos().visible && this.items_dict->len() > 0
            this.id->popup_show()
            this.idp->popup_show()
        endif
        return (max_items > 0 && this.filtered_items[0]->len() > max_items) ? false : true
    enddef

    def _GetFilteredItems(lst: list<dict<any>>, ctx: string): list<any>
        if ctx->empty()
            return [lst, [lst]]
        else
            var filtered = lst->matchfuzzypos(ctx, {key: "text"})
            return [lst, filtered]
        endif
    enddef

    def _Printify(itemsAny: list<any>): list<any>
        if itemsAny->len() > 1
            return itemsAny[0]->mapnew((idx, v) => {
                return {text: v.text, props: itemsAny[1][idx]->mapnew((_, c) => {
                    return {col: v.text->byteidx(c) + 1, length: 1, type: 'ScopeMenuMatch'}
                })}
            })
        else
            return itemsAny->empty() ? [] : itemsAny[0]
        endif
    enddef

    def _CursorSet()
        this.idp->clearmatches()
        var bytepos = options.promptchar->strcharlen() + 2 +
            this.prompt->strcharpart(0, this.cursorpos - 3)->len()
        matchaddpos('ScopeMenuCursor', [[1, bytepos]], 10, -1, {window: this.idp})
    enddef
endclass

export def NewFilterMenu(title: string, items_dict: list<dict<any>>, Callback: func(any, string), Setup: func(number, number) = null_function, GetFilteredItems: func(list<any>, string): list<any> = null_function, Cleanup: func() = null_function, maximize: bool = false): FilterMenu
    return FilterMenu.new(title, items_dict, Callback, Setup, GetFilteredItems, Cleanup, maximize)
enddef
