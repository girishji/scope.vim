<h1 align="center"> Scope </h1>

<h4 align="center"> Minimal, fast, async, robust, and extensible fuzzy finder for Vim. </h4>

<p align="center">
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a>
</p>

![Demo](img/demo.jpeg)

There are already some good implementations of this kind. See
[fuzzyy](https://github.com/Donaldttt/fuzzyy) and
[fzf](https://github.com/junegunn/fzf). This plugin is minimal but has all the features except
for the preview window (which I do not find useful). The core functionality is implemented in two files, with a
total of ~300 lines of code.

It is easy to extend the functionality to <a href="#Search-Interesting-Things">fuzzy search anything</a>.

## Usage

Map the following methods to your favorite keys.

#### Find File

Search for files in the current working directory.

```
vim9script
import 'fuzzyscope.vim' as scope
nnoremap <leader><space> <scriptcmd>scope.fuzzy.File()<CR>
```

Search for installed Vim files.

```
vim9script
import 'fuzzyscope.vim' as scope
nnoremap <leader>fv <scriptcmd>scope.fuzzy.File("find " .. $VIMRUNTIME .. " -type f -print -follow")<CR>
```

Use [fd](https://github.com/sharkdp/fd) instead of `find` command.

```
vim9script
import 'fuzzyscope.vim' as scope
nnoremap <leader>ff <scriptcmd>scope.fuzzy.File('fd -tf --follow')<CR>
```

Method `scope.fuzzy.Find()` takes a string argument. Set this to the full command
used for finding files. Directory tree is traversed by a separate spawned job,
so it never freezes no matter how many thousand files you have in the tree.

### Grep

Live grep in the directory. To grep the same keyword the second time, there is
no need to type again. Previous grep string appears as muted virtual text in
the prompt. Simply type `<Right>` or `<PgDn>` key to fill in and grep again.

```
vim9script
import 'fuzzyscope.vim' as scope
nnoremap <leader>g <scriptcmd>scope.fuzzy.Grep()<CR>
# '.git' directory is excluded from search.
```

Define your own grep command.

```
vim9script
import 'fuzzyscope.vim' as scope
nnoremap <leader>G <scriptcmd>scope.fuzzy.Grep('grep --color=never -RESIHin --exclude="*.git*" --exclude="*.swp" --exclude="*.zwc" --exclude-dir=plugged')<CR>
```

### Switch Buffers

```
vim9script
import 'fuzzyscope.vim' as scope
nnoremap <leader><bs> <scriptcmd>scope.fuzzy.Buffer()<CR>
```

Search unlisted buffers as well.

```
vim9script
import 'fuzzyscope.vim' as scope
nnoremap <leader><bs> <scriptcmd>scope.fuzzy.Buffer(true)<CR>
```

### Others

You can map the following methods to keys.

```
vim9script
import 'fuzzyscope.vim' as scope
```

See `autoload/scope/fuzzy.vim` for implementation.

Method|Description
------|-----------
scope.fuzzy.Keymap() | Key mappings
scope.fuzzy.Help() | Help topics
scope.fuzzy.Highlight() | Highlight groups
scope.fuzzy.Window() | Open windows
scope.fuzzy.Template() | Files in `~/.vim/templates` directory
scope.fuzzy.CmdHistory() | Command history
scope.fuzzy.Filetype() | File types
scope.fuzzy.Colorscheme() | Available color schemes
scope.fuzzy.GitFile() | Git files
scope.fuzzy.MRU() | `:h v:oldfiles`

### Search Interesting Things

This is just an example. To fuzzy search for function definitions, classes, and other
useful artifacts in Python code, put the following in
`~/.vim/after/ftplugin/python.vim`. This technique is powerful when dealing
with large files, especially if you find `:h folds` inconvenient.

```
if exists('g:loaded_scope')
    import 'fuzzyscope.vim' as fuzzy
    def Things()
        var things = []
        for nr in range(1, line('$'))
            var line = getline(nr)
            if line =~ '\(^\|\s\)\(def\|class\) \k\+('
                    || line =~ 'if __name__ == "__main__":'
                things->add({text: $"{line} ({nr})", linenr: nr})
            endif
        endfor
        fuzzy.FilterMenuFactory("Py Things", things,
            (res, key) => {
                exe $":{res.linenr}"
                normal! zz
            },
            (winid, _) => {
                win_execute(winid, $"syn match FilterMenuLineNr '(\\d\\+)$'")
                hi def link FilterMenuLineNr Comment
            })
    enddef
    nnoremap <buffer> <space>/ <scriptcmd>Things()<CR>
endif
```

## Requirements

- Vim version 9.1 or higher

## Installation

Install this plugin via [vim-plug](https://github.com/junegunn/vim-plug).

<details><summary><b>Show instructions</b></summary>
<br>
  
Using vim9 script:

```vim
vim9script
plug#begin()
Plug 'girishji/scope.vim'
plug#end()
```

Using legacy script:

```vim
call plug#begin()
Plug 'girishji/scope.vim'
call plug#end()
```

</details>

Install using Vim's built-in package manager.

<details><summary><b>Show instructions</b></summary>
<br>
  
```bash
$ mkdir -p $HOME/.vim/pack/downloads/opt
$ cd $HOME/.vim/pack/downloads/opt
$ git clone https://github.com/girishji/scope.vim.git
```

Add the following line to your $HOME/.vimrc file.

```vim
packadd scope.vim
```

</details>

#### Credits

Some chunks shamelessly ripped from [habamax](https://github.com/habamax/.vim/blob/master/autoload/).
