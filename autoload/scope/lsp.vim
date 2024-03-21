vim9script

if !exists('g:loaded_lsp')
    echoerr 'LSP client not found'
    finish
endif

import autoload 'lsp/lsp.vim'
import autoload 'lsp/buffer.vim' as buf
import autoload 'lsp/util.vim' as buf

export def DocumentSymbols()
    var fname: string = @%
    if fname->empty()
        return
    endif
    var lspserver: dict<any> = buf.CurbufGetServerChecked('documentSymbol')
    if lspserver->empty() || !lspserver.running || !lspserver.ready
        return
    endif
    if !lspserver.isDocumentSymbolProvider
        util.ErrMsg('LSP server does not support getting list of symbols')
        return
    endif

    var params = {textDocument: {uri: util.LspFileToUri(fname)}}
    lspserver.rpc_a('textDocument/documentSymbol', params, (_, reply) => {
            symbol.DocSymbolPopup(lspserver, reply, fname)
    })
enddef
