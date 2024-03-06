<h1 align="center"> Scope </h1>

<h4 align="center"> Minimal, fast, and async fuzzy finder for Vim. </h4>

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

Map the following functions to your favorite keys.

#### Find File

Search for files in the current working directory.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <leader><space> <scriptcmd>fuzzy.File()<CR>
```

Search for installed Vim files.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <leader>fv <scriptcmd>fuzzy.File("find " .. $VIMRUNTIME .. " -type f -print -follow")<CR>
```

Use [fd](https://github.com/sharkdp/fd) instead of `find` command.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <leader>ff <scriptcmd>fuzzy.File('fd -tf --follow')<CR>
```

> [!NOTE]
> Function `fuzzy.Find()` takes a string argument. Set this to the command used for finding files.
> Directories are traversed by a spawned job, so Vim remains responsive when gathering large directories.

### Grep

Live grep in the directory.

> [!NOTE]
> To grep the same keyword the second time, it is not necessary to type again. Prompt already contains the previous grep string as virtual text. Simply type `<Right>` or `<PgDn>` key to fill in and continue, or type over it to dismiss.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <leader>g <scriptcmd>fuzzy.Grep()<CR>
```

Define your own grep command.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <leader>G <scriptcmd>fuzzy.Grep('grep --color=never -RESIHin --exclude="*.git*" --exclude="*.swp" --exclude="*.zwc" --exclude-dir=plugged')<CR>
```

### Switch Buffers

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <leader><bs> <scriptcmd>fuzzy.Buffer()<CR>
```

Search unlisted buffers as well.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <leader><bs> <scriptcmd>fuzzy.Buffer(true)<CR>
```

### Others

You can map the following functions to keys.

```
vim9script
import autoload 'scope/fuzzy.vim'
```

Method|Description
------|-----------
`fuzzy.Keymap()` | Key mappings
`fuzzy.Help()` | Help topics
`fuzzy.Highlight()` | Highlight groups
`fuzzy.Window()` | Open windows
`fuzzy.Template()` | Files in `~/.vim/templates` directory
`fuzzy.CmdHistory()` | Command history
`fuzzy.Filetype()` | File types
`fuzzy.Colorscheme()` | Available color schemes
`fuzzy.GitFile()` | Git files
`fuzzy.MRU()` | `:h v:oldfiles`

See `autoload/scope/fuzzy.vim` for implementation.

### Search Interesting Things

This is just an example. To fuzzy search for function definitions, classes, and other
useful artifacts in Python code, put the following in
`~/.vim/after/ftplugin/python.vim`.

```
if exists('g:loaded_scope')
    import autoload 'scope/fuzzy.vim'
    def Things()
        var things = []
        for nr in range(1, line('$'))
            var line = getline(nr)
            if line =~ '\(^\|\s\)\(def\|class\) \k\+('
                    || line =~ 'if __name__ == "__main__":'
                things->add({text: $"{line} ({nr})", linenr: nr})
            endif
        endfor
        fuzzy.FilterMenu.new("Py Things", things,
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

See `autoload/scope/fuzzy.vim` for inspiration.

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

## Configuration

Popup window appearance can be configured. `borderchars`, `borderhighlight`, `highlight`,
`scrollbarhighlight`, `thumbhighlight` and  other `:h popup_create-arguments` can be
configured using `g:ScopePopupOptionsSet()`.

To set border of popup window to `Comment` highlight group:

```
g:ScopePopupOptionsSet({borderhighlight: ['Comment']})
```

`ScopeMenuMatch` highlight group modifies the look of characters searched so far.
`ScopeMenuVirtualText` is for the virtual text in Grep window. For other groups
see `autoload/scope/fuzzy.vim`.

### Credits

Some chunks shamelessly ripped from [habamax](https://github.com/habamax/.vim/blob/master/autoload/).

**Open an issue if you encounter errors.**
