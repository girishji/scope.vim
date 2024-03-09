vim9script

export var options = {
    borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    bordercharsp: ['─', '│', '═', '│', '┌', '┐', '╡', '╞'],
    borderhighlight: ['Normal'],
    highlight: 'Normal',
    scrollbarhighlight: 'PmenuSbar',
    thumbhighlight: 'PmenuThumb',
    promptchar: '>',
    # cursorchar: '█',
}

export def OptionsSet(opt: dict<any>)
    options->extend(opt)
enddef

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
            drag: 0,
            wrap: 0,
            cursorline: false,
            padding: [0, 1, 0, 1],
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
        endif
        this.id->popup_settext(this._Printify(this.filtered_items))
        # this.idp->popup_settext($'{options.promptchar} {this.prompt}{options.cursorchar}')
        this.idp->popup_settext($'{options.promptchar} {this.prompt} ')
        this.idp->clearmatches()
        matchaddpos('ScopeMenuCursor', [[1, 3 + this.prompt->len()]], 10, -1, {window: this.idp})

        var pos = this.id->popup_getpos()
        var new_width = pos.core_width
        if new_width > this.minwidth
            this.minwidth = new_width
            popup_move(this.id, {minwidth: this.minwidth})
            var widthp = this.minwidth + (pos.scrollbar ? 1 : 0)
            popup_move(this.idp, {minwidth: widthp, maxwidth: widthp})
        else
            var widthp = this.minwidth + (pos.scrollbar ? 1 : 0)
            popup_move(this.idp, {minwidth: widthp, maxwidth: widthp})
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
        this.minwidth = (&columns * 0.6)->float2nr()
        this.maxwidth = (&columns - 14)
        if maximize
            this.minwidth = this.maxwidth
        endif
        var ignore_input = ["\<cursorhold>", "\<ignore>", "\<Nul>",
                    \ "\<LeftMouse>", "\<LeftRelease>", "\<LeftDrag>", $"\<2-LeftMouse>",
                    \ "\<RightMouse>", "\<RightRelease>", "\<RightDrag>", "\<2-RightMouse>",
                    \ "\<MiddleMouse>", "\<MiddleRelease>", "\<MiddleDrag>", "\<2-MiddleMouse>",
                    \ "\<MiddleMouse>", "\<MiddleRelease>", "\<MiddleDrag>", "\<2-MiddleMouse>",
                    \ "\<X1Mouse>", "\<X1Release>", "\<X1Drag>", "\<X2Mouse>", "\<X2Release>", "\<X2Drag>",
                    \ "\<ScrollWheelLeft", "\<ScrollWheelRight>"
        ]
        # this sequence of bytes are generated when left/right mouse is pressed and
        # mouse wheel is rolled
        var ignore_input_wtf = [128, 253, 100]

        this.idp = popup_create([$'{options.promptchar}  '],
            this._CommonProps(options.bordercharsp, pos_top, 1)->extend({
            title: $" ({items_count}/{items_count}) {this.title} ",
            }))
        matchaddpos('ScopeMenuCursor', [[1, 3]], 10, -1, {window: this.idp})

        this.id = popup_create([],
            this._CommonProps(options.borderchars, pos_top + 3, height)->extend({
                border: [0, 1, 1, 1],
                filter: (id, key) => {
                    items_count = this.items_dict->len()
                    if key == "\<esc>"
                        popup_close(this.idp, -1)
                        popup_close(id, -1)
                        if Cleanup != null_function
                            Cleanup()
                        endif
                    elseif ["\<cr>", "\<C-j>", "\<C-v>", "\<C-t>", "\<C-o>"]->index(key) > -1
                            && this.filtered_items[0]->len() > 0 && items_count > 0
                        popup_close(this.idp, -1)
                        popup_close(id, {idx: getcurpos(id)[1], key: key})
                    elseif key == "\<Right>" || key == "\<PageDown>"
                        if this.idp->getmatches()->indexof((_, v) => v.group == 'ScopeMenuVirtualText') != -1
                            # virtual text present. grep using virtual text.
                            this.prompt = this.idp->getwininfo()[0].bufnr->getbufline(1)[0]->slice(2)
                            var GetFilteredItemsFn = GetFilteredItems == null_function ? this._GetFilteredItems : GetFilteredItems
                            [this.items_dict, this.filtered_items] = GetFilteredItemsFn(this.items_dict, this.prompt)
                            this._SetPopupContent()
                        else
                            win_execute(id, 'normal! ' .. "\<C-d>")
                        endif
                    elseif key == "\<Left>" || key == "\<PageUp>"
                        win_execute(id, 'normal! ' .. "\<C-u>")
                    elseif key == "\<tab>" || key == "\<C-n>" || key == "\<Down>" || key == "\<ScrollWheelDown>"
                        var ln = getcurpos(id)[1]
                        win_execute(id, "normal! j")
                        if ln == getcurpos(id)[1]
                            win_execute(id, "normal! gg")
                        endif
                    elseif key == "\<S-tab>" || key == "\<C-p>" || key == "\<Up>" || key == "\<ScrollWheelUp>"
                        var ln = getcurpos(id)[1]
                        win_execute(id, "normal! k")
                        if ln == getcurpos(id)[1]
                            win_execute(id, "normal! G")
                        endif
                    # Ignoring fancy events and double clicks, which are 6 char long: `<80><fc> <80><fd>.`
                    elseif ignore_input->index(key) == -1 && strcharlen(key) != 6 && str2list(key) != ignore_input_wtf
                        if key == "\<C-U>"
                            if this.prompt == ""
                                return true
                            endif
                            this.prompt = ""
                        elseif (key == "\<C-h>" || key == "\<bs>")
                            if this.prompt == ""
                                return true
                            endif
                            if this.prompt != null_string
                                this.prompt = this.prompt->strcharpart(0, this.prompt->strchars() - 1)
                            endif
                        elseif key =~ '\p'
                            this.prompt = this.prompt .. key
                        endif
                        var GetFilteredItemsFn = GetFilteredItems == null_function ? this._GetFilteredItems : GetFilteredItems
                        [this.items_dict, this.filtered_items] = GetFilteredItemsFn(this.items_dict, this.prompt)
                        this._SetPopupContent()
                    endif
                    return true
                },
                callback: (id, result) => {
                    popup_close(this.idp, -1)
                    if result->type() == v:t_number
                        if result > 0
                            Callback(this.filtered_items[0][result - 1], "")
                        endif
                    else
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
        var height = &lines - 8
        if !this.maximize
            height = min([height, max([items_count, 5])])
        endif
        var pos_top = ((&lines - height) / 2) - 1
        return [height, pos_top]
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
            if itemsAny[0]->empty()
                return []
            else
                return itemsAny[0]->mapnew((_, v) => {
                    return {text: v.text}
                })
            endif
        endif
    enddef
endclass

# some chunks shamelessly ripped from habamax
#   https://github.com/habamax/.vim/blob/master/autoload/popup.vim

