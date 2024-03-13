<h1 align="center"> Scope </h1>

<h4 align="center">Minimal, fast, and extensible fuzzy finder for Vim. </h4>

<p align="center">
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a>
</p>

![Demo](https://gist.githubusercontent.com/girishji/40e35cd669626212a9691140de4bd6e7/raw/6041405e45072a7fbc4e352cbd461e450a7af90e/scope-demo.gif)

There are already good implementations of this kind, such as [fuzzyy](https://github.com/Donaldttt/fuzzyy) and [fzf](https://github.com/junegunn/fzf). This plugin, while minimal, encompasses all essential features, excluding the preview window, which I consider non-essential. The feature set and key mappings align closely with [nvim-telescope](https://github.com/nvim-telescope/telescope.nvim). The main guts are in just two files, totaling around 300 lines of code. It's a concise and easy-to-understand.

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

##### API

```
# findCmd: <string> : Command string as you'd use in a shell. If omitted, uses 'find' or 'fd' (if installed).
# count: <number> : Maximum number of files returned.
def File(findCmd: string = null_string, count: number = 10000)
```

### Live Grep

Unlike fuzzy search `grep`, command is executed  after each keystroke in a dedicated external job. Result updates occur every 100 milliseconds, ensuring real-time feedback. To maintain Vim's responsiveness, lengthy processes may be terminated. An ideal scenario involves launching Vim within the project directory, initiating a grep search, and iteratively refining your query until you pinpoint the desired result. Notably, when editing multiple files, you need not re-enter the grep string for each file. Refer to the note below for further details.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep()<CR>
```

> [!NOTE]
> 1. To perform a second grep with the same keyword, there's no need to retype it. The prompt conveniently retains the previous grep string as virtual text. Simply input `<Right>` or `<PgDn>` to auto-fill and proceed, or overwrite it as needed. For smaller projects, you can efficiently execute repeated greps without relying on the quickfix list.
> 2. Special characters can be entered into the prompt window directly without requiring backslash escaping.

Define your own grep command:

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep('grep --color=never -RESIHin --exclude="*.git*" --exclude="*.swp" --exclude="*.zwc" --exclude-dir=plugged')<CR>
# ripgrep (place excluded paths in ~/.rgignore)
nnoremap <your_key> <scriptcmd>fuzzy.Grep('rg --vimgrep --no-heading --smart-case')<CR>
# silvergrep
nnoremap <your_key> <scriptcmd>fuzzy.Grep('ag --vimgrep')<CR>
```

`grep` command string is echoed in the command line after each search. You can set an option to turn this off (see below).

##### API

```
# grepCmd: <string> : Command string as you'd use in a shell. If omitted, uses 'grep'.
# ignorecase: <bool> : Strictly for syntax highlighting. Should match the option given to 'grep'.
def Grep(grepCmd: string = '', ignorecase: bool = true)
```

To optimize responsiveness, consider fine-tuning `Grep()` settings, particularly for larger projects and slower systems. For instance, adjusting `timer_delay` to a higher value can help alleviate jitteriness during fast typing or clipboard pasting. Additionally, `grep_poll_interval` dictates the initial responsiveness of the prompt for the first few typed characters.

Here's a breakdown of available options:

| Option             | Type    | Description
|--------------------|---------|------------
| grep_poll_interval | number  | Controls how frequently the pipe (of spawned job) is checked and results are displayed. Specified in milliseconds. Default: 20.
| timer_delay        | number  | Delay (in milliseconds) before executing the grep command. Default: 20.
| grep_throttle_len  | number  | Grep command is terminated after `grep_poll_interval` if the typed characters are below this threshold. Default: 3.
| grep_skip_len      | number  | Specifies the minimum number of characters required to invoke the grep command. Default: 0.
| grep_echo_cmd      | boolean | Determines whether to display the grep command string on the command line. Default: `true`.

To optimize performance, adjust these options accordingly:

```
scope#fuzzy#OptionsSet({
    grep_echo_cmd: false,
    ...
})
```

or

```
import autoload 'scope/fuzzy.vim'
fuzzy.OptionsSet({
    grep_echo_cmd: false,
    ...
})
```

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

##### API

```
# list_all_buffers: <bool> : If 'true', include unlisted buffers as well.
def Buffer(list_all_buffers: bool = false)
```

### Search Current Buffer

Enter a word in the prompt, and it will initiate a fuzzy search within the current buffer. The prompt conveniently displays the word under the cursor (`<cword>`) or the previously searched word as virtual text. Use `<Right>` or `<PgDn>` to auto-fill and continue, or type over it.

```
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.BufSearch()<CR>
```

##### API

```
# word_under_cursor: <bool> : Put the word under cursor (<cword>) into the prompt always.
# recall: <bool> : Put previously searched word or <cword> into the prompt.
def BufSearch(word_under_cursor: bool = false, recall: bool = true)
```

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
`fuzzy.Filetype()` | File types
`fuzzy.GitFile()` | Files under git
`fuzzy.Help()` | Help topics
`fuzzy.Highlight()` | Highlight groups
`fuzzy.Keymap()` | Key mappings, to to their declaration on `<cr>`
`fuzzy.MRU()` | `:h v:oldfiles`
`fuzzy.Tag()` | `:h ctags` search
`fuzzy.Autocmd()` | Vim autocommands, go to their declaration on `<cr>`
`fuzzy.Command()` | Vim commands
`fuzzy.Mark()` | Vim marks (`:h mark-motions`)
`fuzzy.Option()` | Vim options and their values
`fuzzy.Register()` | Vim registers, paste contents on `<cr>`
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

### Key Mappings

When popup window is open the following key mappings can be used.

Mapping | Action
--------|-------
`<Right>/<PageDown>` | Page down
`<Left>/<PageUp>` | Page up
`<tab>/<C-n>/<Down>/<ScrollWheelDown>` | Next item
`<S-tab>/<C-p>/<Up>/<ScrollWheelUp>` | Previous item
`<Esc>/<C-c>` | Close
`<CR>` | Confirm selection
`<C-j>` | Go to file selection in a split window
`<C-v>` | Go to file selection in a vertical split
`<C-t>` | Go to file selection in a tab
`<C-r><C-w>` | Insert word under cursor (<cword>) into prompt

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

Following highlight groups modify the content of popup window:

- `ScopeMenuMatch`: Modifies characters searched so far. Default: Linked to `Special`.
- `ScopeMenuVirtualText`: Virtual text in the Grep window. Default: Linked to `Comment`.
- `ScopeMenuSubtle`: Line number, file name, and path. Default: Linked to `Comment`.
- `ScopeMenuCurrent`: Special item indicating current status (used only when relevant). Default: Linked to `Statement`.

## Credits

Some portions of this code are shamelessly ripped from [habamax](https://github.com/habamax/.vim/blob/master/autoload/).

## Other Plugins to Enhance Your Workflow

1. [**devdocs.vim**](https://github.com/girishji/devdocs.vim) - browse documentation from [devdocs.io](https://devdocs.io).

2. [**easyjump.vim**](https://github.com/girishji/easyjump.vim) - makes code navigation a breeze.

3. [**fFtT.vim**](https://github.com/girishji/fFtT.vim) - accurately target words in a line.

4. [**autosuggest.vim**](https://github.com/girishji/autosuggest.vim) - live autocompletion for Vim's command line.

5. [**vimcomplete**](https://github.com/girishji/vimcomplete) - enhances autocompletion in Vim.
