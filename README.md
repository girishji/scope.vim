<h1 align="center"> Scope </h1>

<h4 align="center">Minimal, fast, and extensible fuzzy finder for Vim. </h4>

<p align="center">
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a>
</p>

![Demo](https://gist.githubusercontent.com/girishji/40e35cd669626212a9691140de4bd6e7/raw/afd35c9db9bdfacf77f8240f467b49e28562ace3/scope-demo.gif)

There are already good implementations of this kind, such as [fuzzyy](https://github.com/Donaldttt/fuzzyy) and [fzf](https://github.com/junegunn/fzf). This plugin, while minimal, encompasses all essential features, excluding the preview window, which I consider non-essential. The emphasis is on performance -- pushing the essential features to their limits, and eliminating any unnecessary clutter. The feature set and key mappings align closely with [nvim-telescope](https://github.com/nvim-telescope/telescope.nvim). The code is concise and easy-to-understand.

<a href="#Writing-Your-Own-Extension">Extending the functionality</a> to perform fuzzy searches for other items is straightforward.

## Usage

Map the following functions to your favorite keys.

In the following examples, replace `<your_key>` with the desired key combination.

### Find File

Find files in the current working directory. Files are retrieved through an external job, and the window seamlessly refreshes to display real-time results.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File()<CR>
```

> [!NOTE]
> If you are using legacy script to map keys, use:
>
> `nnoremap <your_key> <scriptcmd>vim9cmd scope#fuzzy#File()<CR>`
>
> Same pattern applies to other mappings also.

Search for installed Vim files:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File("find " .. $VIMRUNTIME .. " -type f -print -follow")<CR>
```

Use [fd](https://github.com/sharkdp/fd) instead of `find` command, and limit the maximum number of files returned by external job to 100,000 (default is 10,000):

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File('fd -tf --follow', 100000)<CR>
```

##### API

```vim
# findCmd: String : Command string as you'd enter in a shell. If omitted, uses
#                   'fd' (if installed) or 'find'.
# count: Number : Maximum number of files returned.
def File(findCmd: string = null_string, count: number = 10000)
```

### Live Grep

Unlike fuzzy search `grep`, command is executed  after each keystroke in a dedicated external job. Result updates occur every 100 milliseconds, ensuring real-time feedback. To maintain Vim's responsiveness, lengthy processes may be terminated. An ideal scenario involves launching Vim within the project directory, initiating a grep search, and iteratively refining your query until you pinpoint the desired result. Notably, when editing multiple files, you need not re-enter the grep string for each file. Refer to the note below for further details.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep()<CR>
```

> [!NOTE]
> 1. To perform a second grep with the same keyword, there's no need to retype it. The prompt conveniently retains the previous grep string as virtual text. Simply input `<Right>` or `<PgDn>` to auto-fill and proceed, or overwrite it as needed. For smaller projects, you can efficiently execute repeated greps without relying on the quickfix list.
> 2. Special characters can be entered into the prompt window directly without requiring backslash escaping.

Define your own grep command:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep('grep --color=never -REIHns --exclude={"*.git*","*.swp","*.zwc"}')<CR>
# ripgrep
nnoremap <your_key> <scriptcmd>fuzzy.Grep('rg --vimgrep --no-heading --smart-case')<CR>
# silvergrep
nnoremap <your_key> <scriptcmd>fuzzy.Grep('ag --vimgrep')<CR>
# Search the word under cursor
nnoremap <your_key> <scriptcmd>fuzzy.Grep(null_string, true, '<cword>')<CR>
```

`grep` command string is echoed in the command line after each search. You can set an option to turn this off (see below).

##### API

```vim
# grepCmd: String : Command string as you'd use in a shell. If omitted, uses 'grep'.
# ignorecase: Boolean : Strictly for syntax highlighting. Should match the 'ignorecase'
#                       option given to 'grep'.
# cword: String : If not null_string, put the word under cursor into the prompt.
#                 Allowable values are '<cword>' and '<cWORD>'.
def Grep(grepCmd: string = null_string, ignorecase: bool = true, cword: string = null_string)
```

To optimize responsiveness, consider fine-tuning `Grep()` settings, particularly for larger projects and slower systems. For instance, adjusting `timer_delay` to a higher value can help alleviate jitteriness during fast typing or clipboard pasting. Additionally, `grep_poll_interval` dictates the initial responsiveness of the prompt for the first few typed characters.

Here's a breakdown of available options:

| Option             | Type    | Description
|--------------------|---------|------------
| `grep_poll_interval` | `Number`  | Controls how frequently the pipe (of spawned job) is checked and results are displayed. Specified in milliseconds. Default: `20`.
| `timer_delay`        | `Number`  | Delay (in milliseconds) before executing the grep command. Default: `20`.
| `grep_throttle_len`  | `Number`  | Grep command is terminated after `grep_poll_interval` if the typed characters are below this threshold. Default: `3`.
| `grep_skip_len`      | `Number`  | Specifies the minimum number of characters required to invoke the grep command. Default: `0`.
| `grep_echo_cmd`      | `Boolean` | Determines whether to display the grep command string on the command line. Default: `true`.

To optimize performance, adjust these options accordingly:

```vim
scope#fuzzy#OptionsSet({
    grep_echo_cmd: false,
    # ...
})
```

or

```vim
import autoload 'scope/fuzzy.vim'
fuzzy.OptionsSet({
    grep_echo_cmd: false,
    # ...
})
```

### Switch Buffer

Switching buffers becomes effortless with fuzzy search. When no input is provided, it automatically selects the alternate buffer.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Buffer()<CR>
```

Search unlisted buffers as well.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Buffer(true)<CR>
```

##### API

```vim
# list_all_buffers: Boolean : If 'true', include unlisted buffers as well.
def Buffer(list_all_buffers: bool = false)
```

### Search Current Buffer

Enter a word in the prompt, and it will initiate a fuzzy search within the current buffer. The prompt conveniently displays the word under the cursor (`<cword>`) or the previously searched word as virtual text. Use `<Right>` or `<PgDn>` to auto-fill and continue, or type over it.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.BufSearch()<CR>
# Search the word under cursor
nnoremap <your_key> <scriptcmd>fuzzy.BufSearch('<cword>')<CR>
```

##### API

```vim
# cword: String : If not null_string, put the word under cursor into the prompt.
#                 Allowable values are '<cword>' and '<cWORD>'.
# recall: Boolean : Put previously searched word or <cword> into the prompt.
def BufSearch(cword: string = null_string, recall: bool = true)
```

### Quickfix and Location List Integration

While the popup window is open, you can conveniently send all items (unfiltered) to a quickfix list by typing `<C-q>`. For filtered items, utilize `<C-Q>`. Likewise, to direct items to the location list, simply type `<C-l>` or `<C-L>`.

Vim conveniently retains the ten most recently used quickfix and location lists for each window. When creating a new quickfix or location list, you can choose to either append it to the end of the stack or replace existing entries with new ones. This behavior is controlled by the `quickfix_stack` option, which can be set using `fuzzy.OptionsSet()`.

| Option             | Type    | Description
|--------------------|---------|------------
| `quickfix_stack` | `Boolean`  | If `true` a new quickfix list (or location list) is created at the end of the stack and entries are added. Otherwise, replace existing entries in the current quickfix list (or location list) with new entries. Default: `true`.

File list (`File()`), grep (`Grep()`), buffer list (`Buffer()`), word search in a buffer (`BufSearch()`), and git file list (`GitFile()`) provide formatted output containing filename information (and line numbers when available), facilitating seamless navigation. Other fuzzy search commands can also send output to the quickfix or location list, although their utility may be limited.

You have the option to display the contents of the current quickfix or location list in a popup menu for efficient fuzzy searching and navigation. Use the following mappings:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Quickfix()<CR>
nnoremap <your_key> <scriptcmd>fuzzy.Loclist()<CR>
```

The current item is highlighted with an asterisk. You can also navigate to the next error in the list by using the `:cnext` command instead of the popup window.

The entire stack of quickfix and location lists can be displayed in a popup window. Use the following mappings:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.QuickfixHistory()<CR>
nnoremap <your_key> <scriptcmd>fuzzy.LoclistHistory()<CR>
```

After selecting a list from the popup menu of `fuzzy.QuickfixHistory()` or `fuzzy.LoclistHistory()`, you can automatically open the quickfix or location-list window. Add the following autocmd group:

```vim
augroup scope-quickfix-history
    autocmd!
    autocmd QuickFixCmdPost chistory cwindow
    autocmd QuickFixCmdPost lhistory lwindow
augroup END
```

For automatic quickfix or location list window opening after `<C-q>` or `<C-l>` commands, replace `chistory|lhistory` above with `clist|llist`.

### All Functions

You can map the following fuzzy search functions to keys.

Method|Description
------|-----------
`fuzzy.Autocmd()` | Vim autocommands, go to their declaration on `<cr>`
`fuzzy.BufSearch()` | Words in current buffer
`fuzzy.Buffer()` | Open buffers (option to search 'unlisted' buffers)
`fuzzy.CmdHistory()` | Command history
`fuzzy.Colorscheme()` | Available color schemes
`fuzzy.Command()` | Vim commands
`fuzzy.File()` | Files in current working directory
`fuzzy.Filetype()` | File types
`fuzzy.GitFile()` | Files under git
`fuzzy.Grep()` | Live grep in current working directory (spaces allowed)
`fuzzy.Help()` | Help topics
`fuzzy.Highlight()` | Highlight groups
`fuzzy.Keymap()` | Key mappings, go to their declaration on `<cr>`
`fuzzy.LspDocumentSymbol()` | Symbols supplied by [Lsp](https://github.com/yegappan/lsp)
`fuzzy.Loclist()` | Items in the location list (sets 'current entry')
`fuzzy.LoclistHistory()` | Entries in the location list stack
`fuzzy.MRU()` | `:h v:oldfiles`
`fuzzy.Mark()` | Vim marks (`:h mark-motions`)
`fuzzy.Option()` | Vim options and their values
`fuzzy.Quickfix()` | Items in the quickfix list (sets 'current entry') 
`fuzzy.QuickfixHistory()` | Entries in the quickfix list stack
`fuzzy.Register()` | Vim registers, paste contents on `<cr>`
`fuzzy.Tag()` | `:h ctags` search
`fuzzy.Window()` | Open windows

### Key Mappings

When popup window is open the following key mappings can be used.

Mapping | Action
--------|-------
`<PageDown>` | Page down
`<PageUp>` | Page up
`<tab>/<C-n>/<Down>/<ScrollWheelDown>` | Next item
`<S-tab>/<C-p>/<Up>/<ScrollWheelUp>` | Previous item
`<Esc>/<C-c>` | Close
`<CR>` | Confirm selection
`<C-j>` | Go to file selection in a split window
`<C-v>` | Go to file selection in a vertical split
`<C-t>` | Go to file selection in a tab
`<C-q>` | Send all unfiltered items to the quickfix list (`:h quickfix.txt`)
`<C-Q>` | Send only filtered items to the quickfix list
`<C-l>` | Send all unfiltered items to the location list (`:h location-list`)
`<C-L>` | Send only filtered items to the location list

Prompt window editor key mappings align with Vim's default mappings for command-line editing.

Mapping | Action
--------|-------
`<Left>` | Cursor one character left
`<Right>` | Cursor one character right
`<C-e>/<End>` | Move cursor to the end of line
`<C-b>/<Home>` | Move cursor to the beginning of line
`<C-u>` | Delete characters between cursor and beginning of line
`<C-w>` | Delete word before the cursor
`<S-Left>/<C-Left>` | Cursor one WORD left
`<S-Right>/<C-Right>` | Cursor one WORD right
`<C-Up>/<S-Up>` | Recall history previous
`<C-Down>/<S-Down>` | Recall history next
`<C-r><C-w>` | Insert word under cursor (<cword>) into prompt
`<C-r><C-a>` | Insert WORD under cursor (<cWORD>) into prompt
`<C-r><C-l>` | Insert line under cursor into prompt
`<C-r>` {register} | Insert the contents of a numbered or named register. Between typing CTRL-R and the second character '"' will be displayed to indicate that you are expected to enter the name of a register.

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
other `:h popup_create-arguments`. To wrap long lines set `wrap` to `true`
(default is `false`). To configure these settings, use
`scope#popup#OptionsSet()`.

For example, to set the border of the popup window to the `Comment` highlight group:

```vim
scope#popup#OptionsSet({borderhighlight: ['Comment']})
```

or,

```vim
import autoload 'scope/popup.vim' as sp
sp.OptionsSet({borderhighlight: ['Comment']})
```

Following highlight groups modify the content of popup window:

- `ScopeMenuMatch`: Modifies characters searched so far. Default: Linked to `Special`.
- `ScopeMenuVirtualText`: Virtual text in the Grep window. Default: Linked to `Comment`.
- `ScopeMenuSubtle`: Line number, file name, and path. Default: Linked to `Comment`.
- `ScopeMenuCurrent`: Special item indicating current status (used only when relevant). Default: Linked to `Statement`.

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

Representative code for each of these patterns can be found in `autoload/scope/fuzzy.vim`.

## Credits

Some portions of this code are shamelessly ripped from [habamax](https://github.com/habamax/.vim/blob/master/autoload/).

## Other Plugins to Enhance Your Workflow

1. [**devdocs.vim**](https://github.com/girishji/devdocs.vim) - browse documentation from [devdocs.io](https://devdocs.io).

2. [**easyjump.vim**](https://github.com/girishji/easyjump.vim) - makes code navigation a breeze.

3. [**fFtT.vim**](https://github.com/girishji/fFtT.vim) - accurately target words in a line.

4. [**autosuggest.vim**](https://github.com/girishji/autosuggest.vim) - live autocompletion for Vim's command line.

5. [**vimcomplete**](https://github.com/girishji/vimcomplete) - enhances autocompletion in Vim.

## Contributing

Open an issue if you encounter problems. Pull requests are welcomed.
