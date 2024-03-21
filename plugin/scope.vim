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

command!          FzfAutocmd           call fuzzy.Autocmd()	                    #Vim autocommands, go to their declaration on <cr>
command!          FzfBufSearch         call fuzzy.BufSearch()	                #Words in current buffer
command!          FzfBuffer            call fuzzy.Buffer()	                    #Open buffers (option to search 'unlisted' buffers)
command!          FzfCmdHistory        call fuzzy.CmdHistory()	                #Command history
command!          FzfColorscheme       call fuzzy.Colorscheme()	                #Available color schemes
command!          FzfCommand           call fuzzy.Command()	                    #Vim commands
command!          FzfFile              call fuzzy.File()	                    #Files in current working directory
command!          FzfFiletype          call fuzzy.Filetype()	                #File types
command!          FzfGitFile           call fuzzy.GitFile()	                    #Files under git
command! -nargs=* FzfGrep              call fuzzy.Grep(<f-args>)	            #Live grep in current working directory (spaces allowed)
command!          FzfHelp              call fuzzy.Help()	                    #Help topics
command!          FzfHighlight         call fuzzy.Highlight()	                #Highlight groups
command!          FzfKeymap            call fuzzy.Keymap()	                    #Key mappings, go to their declaration on <cr>
command!          FzfLoclist           call fuzzy.Loclist()	                    #Items in the location list (sets 'current entry')
command!          FzfLoclistHistory    call fuzzy.LoclistHistory()	            #Entries in the location list stack
command!          FzfMRU               call fuzzy.MRU()	                        #:h v:oldfiles
command!          FzfMark              call fuzzy.Mark()	                    #Vim marks (:h mark-motions)
command!          FzfOption            call fuzzy.Option()	                    #Vim options and their values
command!          FzfQuickfix          call fuzzy.Quickfix()	                #Items in the quickfix list (sets 'current entry')
command!          FzfQuickfixHistory   call fuzzy.QuickfixHistory()	            #Entries in the quickfix list stack
command!          FzfRegister          call fuzzy.Register()	                #Vim registers, paste contents on <cr>
command!          FzfTag               call fuzzy.Tag()	                        #:h ctags search
command!          FzfWindow            call fuzzy.Window()	                    #Open windows

