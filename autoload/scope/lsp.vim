vim9script

if !exists('g:loaded_lsp')
    # Do not throw error as it will show up when Vim starts.
    export def DocumentSymbol()
        echo 'Error: Lsp client is not available'
    enddef
    finish
endif

import autoload 'lsp/lsp.vim'
import autoload 'lsp/buffer.vim' as buf
import autoload 'lsp/util.vim'
import autoload 'lsp/symbol.vim'
import './popup.vim'

export def DocumentSymbol()
    if !exists("g:loaded_lsp") || exists(":LspDocumentSymbol") != 2
        echo 'Lsp client is not available'
        return
    endif
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
            symList = GetSymbolsInfoTable(lspserver, bnr, reply)
        else
            GetSymbolsDocSymbol(lspserver, bnr, reply, symList)
        endif

        popup.FilterMenu.new("DocumentSymbol",
            symList->mapnew((_, v) => {
                var r = v.selectionRange
                if r->empty()
                    r = v.range
                endif
                var linenr = r.start.line + 1
                return {text: $'{v.text} ({linenr})', lnum: linenr, data: v}
            }),
            (res, key) => {
                exe $":{res.lnum}"
                normal! zz
            },
            (winid, _) => {
                win_execute(winid, $"syn match FilterMenuLineNr '<.*> (\\d\\+)$'")
                hi def link FilterMenuLineNr Comment
            })
    })
enddef

export def GetSymbolsInfoTable(lspserver: dict<any>,
        bnr: number,
        symbolInfoTable: list<dict<any>>): list<dict<any>>

    var symbolTable: list<dict<any>> = []
    for syminfo in symbolInfoTable
        var symbolType = symbol.SymbolKindToName(syminfo.kind)->tolower()
        var text = syminfo.name
        if syminfo->has_key('containerName') && !syminfo.containerName->empty()
            text ..= $' [{syminfo.containerName}]'
        endif
        text ..= $' <{symbolType}>'
        var r: dict<dict<number>> = syminfo.location.range
        symbolTable->add({text: text, range: r, selectionRange: {}})
    endfor
    return symbolTable
enddef

export def GetSymbolsDocSymbol(lspserver: dict<any>,
        bnr: number,
        docSymbolTable: list<dict<any>>,
        symbolTable: list<dict<any>>,
        parentName: string = '')

    for syminfo in docSymbolTable
        var symbolType = symbol.SymbolKindToName(syminfo.kind)->tolower()
        var sr: dict<dict<number>>  = syminfo.selectionRange
        var r: dict<dict<number>> = syminfo.range
        var text = $'{syminfo.name} {parentName != null_string ? parentName : ""} <{symbolType}>'
        symbolTable->add({text: text, range: r, selectionRange: sr})

        if syminfo->has_key('children')
            # Process all the child symbols
            GetSymbolsDocSymbol(lspserver, bnr, syminfo.children, symbolTable,
                syminfo.name)
        endif
    endfor
enddef
