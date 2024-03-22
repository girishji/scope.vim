vim9script

if !exists('g:loaded_lsp')
    # Do not throw error as it will show up when Vim starts.
    finish
endif

import autoload 'lsp/lsp.vim'
import autoload 'lsp/buffer.vim' as buf
import autoload 'lsp/util.vim'
import autoload 'lsp/symbol.vim'
import './popup.vim'

export def DocumentSymbol()
    var fname: string = @%
    if fname->empty()
        return
    endif
    var lspserver: dict<any> = buf.CurbufGetServerChecked('documentSymbol')
    if lspserver->empty() || !lspserver.running || !lspserver.ready
        echoerr 'LSP server not found'
        return
    endif
    if !lspserver.isDocumentSymbolProvider
        echoerr 'LSP server does not support getting list of symbols'
        return
    endif

    var params = {textDocument: {uri: util.LspFileToUri(fname)}}
    lspserver.rpc_a('textDocument/documentSymbol', params, (_, reply) => {
        if reply->empty()
            echoerr 'LSP reply is empty'
            return
        endif
        var symList: list<dict<any>> = []
        var bnr = fname->bufnr()
        if reply[0]->has_key('location')
            symList = symbol.GetSymbolsInfoTable(lspserver, bnr, reply)
        else
            symbol.GetSymbolsDocSymbol(lspserver, bnr, reply, symList)
        endif

        popup.FilterMenu.new("DocumentSymbol",
            symList->mapnew((_, v) => {
                var r = v.selectionRange
                if r->empty()
                    r = v.range
                endif
                var linenr = r.start.line + 1
                return {text: $'{v.name} ({linenr})', lnum: linenr, data: v}
            }),
            (res, key) => {
                exe $":{res.lnum}"
                normal! zz
            },
            (winid, _) => {
                win_execute(winid, $"syn match FilterMenuLineNr '(\\d\\+)$'")
                hi def link FilterMenuLineNr Comment
            })
    })
enddef
