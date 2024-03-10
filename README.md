<h1 align="center"> Scope </h1>

<h4 align="center">Minimal, fast, and extensible fuzzy finder for Vim. </h4>

<p align="center">
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a>
</p>

![Demo](https://gist.githubusercontent.com/girishji/40e35cd669626212a9691140de4bd6e7/raw/6041405e45072a7fbc4e352cbd461e450a7af90e/scope-demo.gif)

There are already good implementations of this kind, such as [fuzzyy](https://github.com/Donaldttt/fuzzyy) and
[fzf](https://github.com/junegunn/fzf). This plugin, while minimal, encompasses all essential features, excluding the preview window, which I consider non-essential. The core functionality is implemented in two files, totaling approximately 300 lines of code.

<a href="#Writing-Your-Own-Extension">Extending the functionality</a> to perform fuzzy searches for other items is straightforward.

## Usage

Map the following functions to your favorite keys.

In the following examples, replace `<your_key>` with the desired key combination.

### Find File

Find files in the current working directory. Files are retrieved through an external job, and the window seamlessly refreshes to display real-time results.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File()<CR>
```

Search for installed Vim files:

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File("find " .. $VIMRUNTIME .. " -type f -print -follow")<CR>
```

Use [fd](https://github.com/sharkdp/fd) instead of `find` command, and limit the maximum number of files returned by external job to 100,000 (default is 10,000):

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File('fd -tf --follow', 100000)<CR>
```

### Live Grep

Unlike fuzzy search `grep`, command is executed  after each keystroke in a dedicated external job. Result updates occur every 100 milliseconds, ensuring real-time feedback. To maintain Vim's responsiveness, lengthy processes may be terminated. An ideal scenario involves launching Vim within the project directory, initiating a grep search, and iteratively refining your query until you pinpoint the desired result. Notably, when editing multiple files, you need not re-enter the grep string for each file. Refer to the note below for further details.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep()<CR>
```

> [!NOTE]
> 1. Escape spaces with backslash when searching multiple words (e.g., `foo\ bar` to grep for 'foo bar')
> 2. To grep the same keyword a second time, there's no need to retype it. The prompt already contains the previous grep string as virtual text. Simply type `<Right>` or `<PgDn>` key to fill in and continue, or type over it to dismiss.

Define your own grep command:

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep('grep --color=never -RESIHin --exclude="*.git*" --exclude="*.swp" --exclude="*.zwc" --exclude-dir=plugged')<CR>
```

`grep` command string is echoed in the command line after each search. You can set an option to turn this off (see below).

### Switch Buffer

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Buffer()<CR>
```

Search unlisted buffers as well.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Buffer(true)<CR>
```

See `autoload/scope/fuzzy.vim` for implementation.

### Others

You can map the following functions to keys.

```
vim9script
import autoload 'scope/fuzzy.vim'
```

Method|Description
------|-----------
`fuzzy.CmdHistory()` | Command history
`fuzzy.Colorscheme()` | Available color schemes
`fuzzy.CscopeEgrep()` | egrep cscope db (`:cs find e <pat>`)
`fuzzy.Filetype()` | File types
`fuzzy.GitFile()` | Files under git
`fuzzy.Help()` | Help topics
`fuzzy.Highlight()` | Highlight groups
`fuzzy.Keymap()` | Key mappings
`fuzzy.MRU()` | `:h v:oldfiles`
`fuzzy.Tag()` | `:h ctags` search
`fuzzy.VimCommand()` | Vim commands
`fuzzy.Window()` | Open windows

See `autoload/scope/fuzzy.vim` for implementation.

### Writing Your Own Extension

The search functionality encompasses four fundamental patterns:

1. **Obtaining a List and Fuzzy Searching:**

   - This represents the simplest use case, where a list of items is acquired, and fuzzy search is performed on them. Check out this [gist](https://gist.github.com/girishji/e3479918da89890b6e85b9efc4e95da5) for a practical example.

2. **Asynchronous List Update with Fuzzy Search:**
   - In scenarios like file searching, the list of all items is updated asynchronously while concurrently conducting a fuzzy search. See this [gist](https://gist.github.com/girishji/e4dbcb61c1f7292eb884799bc3251b26) for an example.

3. **Dynamic List Update on User Input:**
   - Certain cases, such as handling tags or Vim commands, involve waiting for a new list of items every time the user inputs something.

4. **Asynchronous Relevant Items Update on User Input:**
   - For dynamic searches like live grep, the list is updated asynchronously, but exclusively with relevant items, each time the user types something.

Boilerplate code for each of these patterns can be found in `autoload/scope/fuzzy.vim`. Understand how it handles the different patterns and adapt or extend it according to your use case. Everything is exported.

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

The appearance of the popup window can be customized using `borderchars`,
`borderhighlight`, `highlight`, `scrollbarhighlight`, `thumbhighlight`, and
other `:h popup_create-arguments`. To configure these settings, use
`scope#popup#OptionsSet()`.

For example, to set the border of the popup window to the `Comment` highlight group:

```vim
scope#popup#OptionsSet({borderhighlight: ['Comment']})
```

or,

```
import autoload 'scope/popup.vim' as sp
sp.OptionsSet({borderhighlight: ['Comment']})
```

The `ScopeMenuMatch` highlight group modifies the appearance of characters
searched so far and is linked to `Special` by default.

`ScopeMenuVirtualText` is used for the virtual text in the Grep window.

The appearance of `Grep()` function output can be modified as follows:

```
scope#fuzzy#OptionsSet({
    grep_echo_cmd: true, # whether to display the grep command string on the command line
})
```

or

```
import autoload 'scope/fuzzy.vim'
fuzzy.OptionsSet({
    grep_echo_cmd: true, # whether to display the grep command string on the command line
})
```

## Credits

Some portions of this code are shamelessly ripped from [habamax](https://github.com/habamax/.vim/blob/master/autoload/).

## Other Plugins to Enhance Your Workflow

1. [**devdocs.vim**](https://github.com/girishji/devdocs.vim) - browse documentation from [devdocs.io](https://devdocs.io).

2. [**easyjump.vim**](https://github.com/girishji/easyjump.vim) - makes code navigation a breeze.

3. [**fFtT.vim**](https://github.com/girishji/fFtT.vim) - accurately target words in a line.

4. [**autosuggest.vim**](https://github.com/girishji/autosuggest.vim) - live autocompletion for Vim's command line.

5. [**vimcomplete**](https://github.com/girishji/vimcomplete) - enhances autocompletion in Vim.
