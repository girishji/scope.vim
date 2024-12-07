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

<a href="#Writing-Your-Own-Extension">Extending</a> the functionality to perform fuzzy search for other items is straightforward.

# Usage

Map the following functions to your favorite keys.

In the following examples, replace `<your_key>` with the desired key combination.

To quickly try it out, use the <a href="#commands">commands</a> provided below.

## Find File

Find files in the current working directory. Files are retrieved through an external job, and the window seamlessly refreshes to display real-time results.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File()<cr>
```

> [!TIP]
> If you are using legacy script to map keys, use:
>
> `nnoremap <your_key> <scriptcmd>vim9cmd scope#fuzzy#File()<cr>`<br>
> or<br>
> `nnoremap <your_key> :call g:scope#fuzzy#File()<cr>`
>
> Same pattern applies to other mappings also.
>
> If you're not concerned with customizing the behavior, another option is to simply map keys to <a href="#commands">commands</a>.

### API

```vim
# findCmd: String     : Command string to search for files. If omitted or set to
#                      'null_string', uses 'find' command.
# count: Number       : Maximum number of files returned.
# ignore_err: Boolean : Ignore stderr from 'findCmd', including file permission errors.
def File(findCmd: string = null_string, count: number = 100000, ignore_err: bool = true)
```

> [!NOTE]
> If the `findCmd` argument (above) is either unset or set to `null_string`, the *find* command (accessible from *$PATH)*) is automatically utilized. Under this circumstance, the following conditions apply:
> - Patterns specified in the Vim option `wildignore`, along with patterns present in files `.gitignore`, `~/.gitignore`, `.findignore`, and `~/.findignore`, are excluded. For instance, to prevent the *find* command from traversing into the `.foo` directory or displaying Vim swap files, add the following line to your `.vimrc` file: `set wildignore+=.foo/*,*.swp`. `.git` directory is automatically excluded.
> - `.gitignore` patterns containing `**` or `!` are ignored, since precessing them deteriorates performance.
> - For guidance on setting *wildignore* patterns, refer to `:h autocmd-patterns` within Vim. For similar assistance regarding *gitignore* patterns, consult '[PATTERN FORMAT](https://git-scm.com/docs/gitignore)'.

> [!IMPORTANT]
> The default command utilized by `File()`, which employs the *find* system command and incorporates flags for excluding paths specified in `.gitignore` and `wildignore`, can be accessed via the `FindCmd()` function. The function's API is as follows: `FindCmd(dir: string = '.'): string`. The `dir` argument designates the directory to be searched, with the default being the current directory.

> [!TIP]
> - To **echo the command string** in Vim's command line, set the option `find_echo_cmd` to `true`. Default is `false`. Setting this option helps in debugging arguments given to *find* command. Setting of options is discussed later.
> - To open the filtered results in separate buffers, press `<C-o>`. Alternatively, use `<C-g>` to open them as an argument list (see `:h arglist` for more details).

### Examples

Search for installed Vim files:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File($'find {$VIMRUNTIME} -type f -print -follow')<cr>
# Or, utilize 'FindCmd()' to exclude paths specified in '.gitignore' and 'wildignore':
nnoremap <your_key> <scriptcmd>fuzzy.File(fuzzy.FindCmd($VIMRUNTIME))<CR>
```

Use [fd](https://github.com/sharkdp/fd) instead of `find` command, and limit the maximum number of files returned by external job to 500,000 (default is 100,000):

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File('fd -tf --follow', 500000)<cr>
```

Find files in `~/.vim`:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File(fuzzy.FindCmd($'{$HOME}/.vim'))<CR>
# Use 'fd' instead
nnoremap <your_key> <scriptcmd>fuzzy.File($'fd -tf --follow . {$HOME}/.vim')<cr>
```

If you require the flexibility to search a directory of your choice during runtime, consider creating a command that allows for dynamic directory selection, and optionally, assign a key for quicker access.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
# Define a Vim command called 'ScopeFind' which takes a 'dir' argument (autocompletes directory name):
command -nargs=1 -complete=dir ScopeFile fuzzy.File($'find {<f-args>} -type f -print -follow')
# Or, utilize 'FindCmd()' to exclude paths specified in '.gitignore' and 'wildignore':
command -nargs=1 -complete=dir ScopeFile fuzzy.File(fuzzy.FindCmd(<f-args>))
# Or, use 'fd' instead:
command -nargs=1 -complete=dir ScopeFile fuzzy.File($'fd -tf --follow . {<f-args>}')
# (Optionally) Assign a key:
nnoremap <your_key> :ScopeFile<space>
```

To always search from the root directory of a Git repository, regardless of whether the file is opened from a sub-directory within that repository, you can add the following mapping:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.File(fuzzy.FindCmd($'{system("git rev-parse --show-toplevel 2>/dev/null \|\| true")->trim()}'))<cr>
```

The directory from which to initiate the search can be obtained from any mechanism. Here is the same example using a Vim function:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
def FindGit()
    var gitdir = system("git rev-parse --show-toplevel 2>/dev/null")->trim()
    if v:shell_error != 0 || gitdir == getcwd()
        gitdir = '.'
    endif
    fuzzy.File(fuzzy.FindCmd(gitdir))
enddef
nnoremap <your_key> <scriptcmd>FindGit()<cr>
```

## Live Grep

Unlike fuzzy search, `grep` command is executed  after each keystroke in a dedicated external job. Result updates occur every 100 milliseconds, ensuring real-time feedback. To maintain Vim's responsiveness, lengthy processes may be terminated. An ideal scenario involves launching Vim within the project directory, initiating a grep search, and iteratively refining your query until you pinpoint the desired result. Notably, when editing multiple files, you need not re-enter the grep string for each file. Refer to the tip below for further details.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep()<cr>
```

> [!TIP]
> 1. To perform a second grep with the same keyword, there's no need to retype it. The prompt conveniently retains the previous grep string as virtual text. Simply input `<Right>` or `<PgDn>` to auto-fill and proceed, or overwrite it as needed. For smaller projects, you can efficiently execute repeated greps without relying on the quickfix list.
> 2. Special characters can be entered into the prompt window directly without requiring backslash escaping.
> 3. When working with live grep, it can be advantageous to suspend it temporarily and refine the results through filtering. Press `<C-k>` to enter pattern search mode. For instance, while in pattern search mode, typing `^foo` will selectively display lines starting with `foo`. To negate patterns, prepend `!` to the search term. For instance, to filter lines that do not contain `foo` or `bar`, input `!foo|bar` into the prompt. Whether the pattern is case-sensitive is determined by `ignorecase` Vim option. To force case (in)sensitive search prepend the pattern with `\c` or `\C`. Pressing `<C-k>` again will toggle back to live grep mode.
> 4. To open the filtered results in separate buffers, press `<C-o>`. Alternatively, use `<C-g>` to open them as an argument list (see `:h arglist` for more details).

> [!NOTE]
> `grep` command string is **echoed** in the command line after each search. You can unset `grep_echo_cmd` option to turn this off (see below).

### API

```vim
# grepCmd:    String  : Command string as you'd use in a shell. If omitted, uses 'grep'
#                         and excludes paths specified in 'wildignore'.
# ignorecase: Boolean : Strictly for syntax highlighting. Should match the 'ignorecase'
#                         option given to 'grep'.
# cword:      String  : If not null_string, put the word under cursor into the prompt.
#                         Allowable values are '<cword>' and '<cWORD>'.
# dir:        String  : If not null_string, search in the specified directory instead of the
#                         current directory.
def Grep(grepCmd: string = null_string, ignorecase: bool = true, cword: string = null_string,
             dir: string = null_string)
```

> [!NOTE]
> 1. If the `grepCmd` argument (above) is either not set or set to `null_string`, the *grep* command (accessible from *$PATH*) is automatically utilized. In this scenario, patterns specified in the Vim option 'wildignore' are automatically excluded from *grep* operations. For example, to prevent the *grep* command from traversing into the `.foo` directory, include the following line in your *.vimrc* file: `set wildignore+=.foo/*`. Any pattern within 'wildignore' containing a slash (`/`) is interpreted as a directory (utilizing *grep* option *--exclude-dir*), while others are considered as files (utilizing *grep* option *--exclude*). '.git' directory is always excluded.

> [!IMPORTANT]
> The default command utilized by `Grep()`, which employs the *grep* system command and incorporates flags for excluding paths specified in `wildignore`, can be accessed via the `GrepCmd()` function. The function's API is as follows: `GrepCmd(flags: string = null_string): string`. The `flags` argument defaults to case-insensitive search (when `null_string` is specified). These flags can have minor variations depending on the OS.

To optimize responsiveness, consider fine-tuning `Grep()` settings, particularly for larger projects and slower systems. For instance, adjusting `timer_delay` to a higher value can help alleviate jitteriness during fast typing or clipboard pasting. Additionally, `grep_poll_interval` dictates the initial responsiveness of the prompt for the first few typed characters.

Here's a breakdown of available options:

| Option             | Type    | Description
|--------------------|---------|------------
| `grep_poll_interval` | `Number`  | Controls how frequently the pipe (of spawned job) is checked and results are displayed. Specified in milliseconds. Default: `20`.
| `timer_delay`        | `Number`  | Delay (in milliseconds) before executing the grep command. Default: `20`.
| `grep_throttle_len`  | `Number`  | Grep command is terminated after `grep_poll_interval` if the typed characters are below this threshold. Default: `3`.
| `grep_skip_len`      | `Number`  | Specifies the minimum number of characters required to invoke the grep command. Default: `0`.
| `grep_echo_cmd`      | `Boolean` | Determines whether to display the grep command string on the command line. Default: `true`.

Set these options as follows:

```vim
scope#fuzzy#OptionsSet({
    grep_echo_cmd: false,
    # ...
})
```

or

```vim
vim9script
import autoload 'scope/fuzzy.vim'
fuzzy.OptionsSet({
    grep_echo_cmd: false,
    # ...
})
```

### Examples

Case-sensitive grep:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep('grep --color=never -REIHns --exclude-dir=.git')<cr>
# Or, to exclude patterns specified in 'wildignore':
nnoremap <your_key> <scriptcmd>fuzzy.Grep(fuzzy.GrepCmd('-RESIHns'))<CR>
```

Use ripgrep or silvergrep:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
# ripgrep
nnoremap <your_key> <scriptcmd>fuzzy.Grep('rg --vimgrep --smart-case')<cr>
# silvergrep
nnoremap <your_key> <scriptcmd>fuzzy.Grep('ag --vimgrep')<cr>
```

Search the word under cursor:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep(null_string, true, '<cword>')<cr>
```

grep inside '~/.vim' directory:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Grep(null_string, true, null_string, $'{$HOME}/.vim')<cr>
```

If you need to grep within a specific directory that isn't the current one, consider these two options:

1) Create a keymap where each directory you want to grep is mapped to a unique key. Then, utilize `fuzzy.Grep()` by providing the directory as an argument (refer to the API below). Assign a key to each directory you wish to grep.
2) Alternatively, define a command and optionally assign a key to it. This method enables you to select the directory **dynamically** at runtime.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
# Define a Vim command called 'ScopeGrep' that takes 'dir' argument (autocompletes directory name)
command -nargs=1 -complete=dir ScopeGrep fuzzy.Grep(null_string, true, null_string, <f-args>)
# Map a key (if you prefer)
nnoremap <your_key> :ScopeGrep<space>
# Use ripgrep instread
command -nargs=1 -complete=dir ScopeGrep fuzzy.Grep('rg --vimgrep', true, null_string, <f-args>)
```

## Switch Buffer

Switching buffers becomes effortless with fuzzy search. When no input is provided, it automatically selects the alternate buffer.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Buffer()<cr>
```

Search unlisted buffers as well.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Buffer(true)<cr>
```

Hide unlisted buffers and always use current window

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.Buffer(v:none, false)<cr>
```

### API

```vim
# list_all_buffers: Boolean : If 'true', include unlisted buffers as well.
# goto_window: Boolean : If 'false', do not go to other window.
def Buffer(list_all_buffers: bool = false, goto_window: bool = true )
```

## Search Current Buffer

Enter a word in the prompt, and it will initiate a fuzzy search within the current buffer. The prompt conveniently displays the word under the cursor (`<cword>`) or the previously searched word as virtual text. Use `<Right>` or `<PgDn>` to auto-fill and continue, or type over it.

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.BufSearch()<cr>
# Search the word under cursor
nnoremap <your_key> <scriptcmd>fuzzy.BufSearch('<cword>')<cr>
```

### API

```vim
# cword:  String  : If not null_string, put the word under cursor into the prompt.
#                     Allowable values are '<cword>' and '<cWORD>'.
# recall: Boolean : Put previously searched word or <cword> into the prompt.
def BufSearch(cword: string = null_string, recall: bool = true)
```

## Quickfix and Location List Integration

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
nnoremap <your_key> <scriptcmd>fuzzy.Quickfix()<cr>
nnoremap <your_key> <scriptcmd>fuzzy.Loclist()<cr>
```

The current item is highlighted with an asterisk. You can also navigate to the next error in the list by using the `:cnext` command instead of the popup window.

The entire stack of quickfix and location lists can be displayed in a popup window. Use the following mappings:

```vim
vim9script
import autoload 'scope/fuzzy.vim'
nnoremap <your_key> <scriptcmd>fuzzy.QuickfixHistory()<cr>
nnoremap <your_key> <scriptcmd>fuzzy.LoclistHistory()<cr>
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

## All Functions

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
`fuzzy.Help()` | Vim help topics (_tags_)
`fuzzy.HelpfilesGrep()` | Live grep Vim help files (_doc/*.txt_)
`fuzzy.Highlight()` | Highlight groups
`fuzzy.Jumplist()` | `:h jumplist`
`fuzzy.Keymap()` | Key mappings, go to their declaration on `<cr>`
`fuzzy.LspDocumentSymbol()` | Symbols supplied by [Lsp](https://github.com/yegappan/lsp)
`fuzzy.Loclist()` | Items in the location list (sets 'current entry')
`fuzzy.LoclistHistory()` | Entries in the location list stack
`fuzzy.MRU()` | `:h v:oldfiles` (set `mru_rel_path` option to list relative paths)
`fuzzy.Mark()` | Vim marks (`:h mark-motions`)
`fuzzy.Option()` | Vim options and their values
`fuzzy.Quickfix()` | Items in the quickfix list (sets 'current entry') 
`fuzzy.QuickfixHistory()` | Entries in the quickfix list stack
`fuzzy.Register()` | Vim registers, paste contents on `<cr>`
`fuzzy.Tag()` | `:h ctags` search
`fuzzy.Window()` | Open windows

## Commands

The above functions have equivalent commands that can be invoked from the command line. The primary command is `:Scope`, with the function name as its only argument except for `Grep`. These commands are primarily provided for convenience. The main interface, as described above, is through key mappings.

```vim
:Scope <Autocmd|BufSearch|Buffer|CmdHistory|Colorscheme|Command|File|Filetype|GitFile|Grep|Help|HelpfilesGrep|Highlight|Jumplist|Keymap|LspDocumentSymbol|Loclist|LoclistHistory|MRU|Mark|Option|Quickfix|QuickfixHistory|Register|Tag|Window>
```

For example, to initiate a buffer search, use the command `:Scope Buffer` or `:Scope buffer`. Typing `:Scope <Tab>` will display all available functions.

`Grep` takes additional arguments. `:Scope {Grep|grep} [dir] [str]` starts a live search with 'str' as the initial search string if non-empty. If 'dir' is specified, search in that directory instead of the current directory.

You can map these commands to keys also. For example:

```vim
nnoremap <your_key> <cmd>Scope File<cr>
```

## Key Mappings

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
`<C-k>` | During live grep, toggle between pattern search of results and live grep.
`<C-o>` | Send filtered files to buffer list, where applicable.
`<C-g>` | Send filtered files to argument list, where applicable (`:h arglist`)

Prompt window editor key mappings align with Vim's default mappings for command-line editing.

Mapping | Action
--------|-------
`<Left>` | Cursor one character left
`<Right>` | Cursor one character right
`<C-e>/<End>` | Move cursor to the end of line
`<C-b>/<Home>` | Move cursor to the beginning of line
`<S-Left>/<C-Left>` | Cursor one WORD left
`<S-Right>/<C-Right>` | Cursor one WORD right
`<C-u>` | Delete characters between cursor and beginning of line
`<C-w>` | Delete word before the cursor
`<C-Up>/<S-Up>` | Recall history previous
`<C-Down>/<S-Down>` | Recall history next
`<C-r><C-w>` | Insert word under cursor (`<cword>`) into prompt
`<C-r><C-a>` | Insert WORD under cursor (`<cWORD>`) into prompt
`<C-r><C-l>` | Insert line under cursor into prompt
`<C-r>` {register} | Insert the contents of a numbered or named register. Between typing CTRL-R and the second character '"' will be displayed to indicate that you are expected to enter the name of a register.

To enable emacs-style editing in the prompt window, set the option `emacsKeys` to `true` as follows:

```vim
scope#popup#OptionsSet({emacsKeys: true})
```

or,

```vim
import autoload 'scope/popup.vim' as sp
sp.OptionsSet({emacsKeys: true})
```

When emacs-style editing is enabled, following keybinding take effect:

Mapping | Action
--------|-------
`<C-b>/<Left>` | Cursor one character left
`<C-f>/<Right>` | Cursor one character right
`<C-e>/<End>` | Move cursor to the end of line
`<C-a>/<Home>` | Move cursor to the beginning of line
`<A-b>/<S-Left>/<C-Left>` | Cursor one WORD left
`<A-f>/<S-Right>/<C-Right>` | Cursor one WORD right

# Requirements

- Vim version 9.1 or higher

# Installation

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

# Configuration

The appearance of the popup window can be customized using `borderchars`,
`borderhighlight`, `highlight`, `scrollbarhighlight`, `thumbhighlight`, `maxheight`, `maxwidth`, and
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

## Writing Your Own Extension

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

# Credits

Some portions of this code are shamelessly ripped from [habamax](https://github.com/habamax/.vim/blob/master/autoload/).

# Other Plugins to Enhance Your Workflow

1. [**Devdocs.vim**](https://github.com/girishji/devdocs.vim) - browse documentation from [devdocs.io](https://devdocs.io).

2. [**Vimcomplete**](https://github.com/girishji/vimcomplete) - enhances autocompletion in Vim.

3. [**VimBits**](https://github.com/girishji/vimbits) - curated suite of lightweight Vim plugins.

4. [**VimSuggest**](https://github.com/girishji/vimsuggest) - autocompletion for Vim's command-line.

# Contributing

Open an issue if you encounter problems. Pull requests are welcomed.
