# VHS documentation
#
# Output:
#   Output <path>.gif               Create a GIF output at the given <path>
#   Output <path>.mp4               Create an MP4 output at the given <path>
#   Output <path>.webm              Create a WebM output at the given <path>
#
# Require:
#   Require <string>                Ensure a program is on the $PATH to proceed
#
# Settings:
#   Set FontSize <number>           Set the font size of the terminal
#   Set FontFamily <string>         Set the font family of the terminal
#   Set Height <number>             Set the height of the terminal
#   Set Width <number>              Set the width of the terminal
#   Set LetterSpacing <float>       Set the font letter spacing (tracking)
#   Set LineHeight <float>          Set the font line height
#   Set LoopOffset <float>%         Set the starting frame offset for the GIF loop
#   Set Theme <json|string>         Set the theme of the terminal
#   Set Padding <number>            Set the padding of the terminal
#   Set Framerate <number>          Set the framerate of the recording
#   Set PlaybackSpeed <float>       Set the playback speed of the recording
#   Set MarginFill <file|#000000>   Set the file or color the margin will be filled with.
#   Set Margin <number>             Set the size of the margin. Has no effect if MarginFill isn't set.
#   Set BorderRadius <number>       Set terminal border radius, in pixels.
#   Set WindowBar <string>          Set window bar type. (one of: Rings, RingsRight, Colorful, ColorfulRight)
#   Set WindowBarSize <number>      Set window bar size, in pixels. Default is 40.
#   Set TypingSpeed <time>          Set the typing speed of the terminal. Default is 50ms.
#
# Sleep:
#   Sleep <time>                    Sleep for a set amount of <time> in seconds
#
# Type:
#   Type[@<time>] "<characters>"    Type <characters> into the terminal with a
#                                   <time> delay between each character
#
# Keys:
#   Escape[@<time>] [number]        Press the Escape key
#   Backspace[@<time>] [number]     Press the Backspace key
#   Delete[@<time>] [number]        Press the Delete key
#   Insert[@<time>] [number]        Press the Insert key
#   Down[@<time>] [number]          Press the Down key
#   Enter[@<time>] [number]         Press the Enter key
#   Space[@<time>] [number]         Press the Space key
#   Tab[@<time>] [number]           Press the Tab key
#   Left[@<time>] [number]          Press the Left Arrow key
#   Right[@<time>] [number]         Press the Right Arrow key
#   Up[@<time>] [number]            Press the Up Arrow key
#   Down[@<time>] [number]          Press the Down Arrow key
#   PageUp[@<time>] [number]        Press the Page Up key
#   PageDown[@<time>] [number]      Press the Page Down key
#   Ctrl+<key>                      Press the Control key + <key> (e.g. Ctrl+C)
#
# Display:
#   Hide                            Hide the subsequent commands from the output
#   Show                            Show the subsequent commands in the output

# Disable autocompletion plugins
# colorscheme dracula

Output demo.gif

Set Margin 10
Set MarginFill "#674EFF"
Set BorderRadius 10
Set Padding 10

Set TypingSpeed 200ms
Set FontSize 16
Set Width 1000
Set Height 650
Set Shell "zsh"

Type "vi -n" Sleep 2s Enter

Type "iAGENDA" Enter 2 Escape Sleep 1s
Type "i* Open files and switch buffers" Enter Escape Sleep 2s
Space Space
Sleep 2
Type "p" Sleep 2 Enter
Type "gg"
Sleep 3
Space Space
Sleep 2
Type "sc" Sleep 2s Enter
Type "gg"
Sleep 3
Space Space
Sleep 2
Type "f" Sleep 2s Enter
Type "gg"
Sleep 3
Type ":ls" Sleep 2s Enter Sleep 2s Enter
Sleep 5

Space Backspace
Sleep 3
Type "n" Sleep 2s Enter

Type "o* Live grep" Enter Escape Sleep 2s
Space Type "g"
Sleep 2
Type "e" Sleep 1s Type "x" Sleep 1s Type "e" Sleep 1s Type "c" Sleep 1s
Sleep 2s
Tab Enter
Sleep 3s

Space Backspace
Sleep 3
Type "n" Sleep 2s Enter

Type "o* Command History" Enter Escape Sleep 2s
Space Type "fc"
Sleep 3s
Escape

Type "o* Help Topics" Enter Escape Sleep 2s
Space Type "fH"
Sleep 2
Type "map"
Sleep 2s
Enter
Sleep 3s
Type "q"

Type "o* Send Items from Grep to Quickfix List" Enter Escape Sleep 2s
Space Type "g"
Sleep 2
Type "e" Sleep 1s Type "x" Sleep 1s
Ctrl+q
Sleep 2

Type "o* Fuzzy Search Quickfix List" Enter Escape Sleep 2s
Space Type "fq"
Type "i" Sleep 1s Type "d" Sleep 1s Type "x" Sleep 1s
Tab
Sleep 2s
Enter
Sleep 4s
Type ":bd" Sleep 1s
Enter
Sleep 2s

Type "o* See README for more examples!" Enter Escape Sleep 2s
Type ":qa!"
Sleep 2s
