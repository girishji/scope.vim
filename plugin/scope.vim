if !has('vim9script') ||  v:version < 901
    echoerr 'Needs Vim version 9.1 and above'
    finish
endif
vim9script

import autoload 'scope/fuzzy.vim'

g:loaded_scope = true

# ripgrep output can include column number. default values of grepformat does
# not contain column pattern, add it.
set grepformat^=%f:%l:%c:%m

command!          ScopeAutocmd           call fuzzy.Autocmd()
command!          ScopeBufSearch         call fuzzy.BufSearch()
command!          ScopeBuffer            call fuzzy.Buffer()
command!          ScopeCmdHistory        call fuzzy.CmdHistory()
command!          ScopeColorscheme       call fuzzy.Colorscheme()
command!          ScopeCommand           call fuzzy.Command()
command!          ScopeFile              call fuzzy.File()
command!          ScopeFiletype          call fuzzy.Filetype()
command!          ScopeGitFile           call fuzzy.GitFile()
command! -nargs=* ScopeGrep              call fuzzy.GrepFast(<f-args>)
command!          ScopeHelp              call fuzzy.Help()
command!          ScopeHighlight         call fuzzy.Highlight()
command!          ScopeKeymap            call fuzzy.Keymap()
command!          ScopeLoclist           call fuzzy.Loclist()
command!          ScopeLoclistHistory    call fuzzy.LoclistHistory()
command!          ScopeMRU               call fuzzy.MRU()
command!          ScopeMark              call fuzzy.Mark()
command!          ScopeOption            call fuzzy.Option()
command!          ScopeQuickfix          call fuzzy.Quickfix()
command!          ScopeQuickfixHistory   call fuzzy.QuickfixHistory()
command!          ScopeRegister          call fuzzy.Register()
command!          ScopeTag               call fuzzy.Tag()
command!          ScopeWindow            call fuzzy.Window()

