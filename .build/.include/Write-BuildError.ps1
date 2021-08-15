function Script:Write-BuildError {
<#
.SYNOPSIS
This function writes output to the host in an opinionated way

.DESCRIPTION
The purpose of this function is to standardize how text is presented
to the user.  The console output is piped to many formatters and then
sent to the console with color formatting and space padding as needed.

.PARAMETER Message
The left section text to send.  Keep this under 80 characters.  I set
the default left section padding to 35 characters.  You can adjust this below.

.PARAMETER Detail
This is the right section text to send.  its best to keep this under
80 characters minus the length of the left section.  i just use this
section to review output...the name of the property from the left section
or the status of ...done with tasks or to mark out variable values

.PARAMETER ColorLeftSide
The foreground color of the left section.  This takes one of the colors from
the [ConsoleColor] enumerator.   This can be ommitted to enable the use of
default colors.

.PARAMETER ColorRightSide
The foreground color of the right section.  This takes one of the colors from
the [ConsoleColor] enumerator.   This can be ommitted to enable the use of
default colors.

.PARAMETER Title
this switch uses the Title formatting style where there is only one section
which uses the Message parameter

.PARAMETER Header
This uses the Header formatting style where there are two sections and right
justify affects the Detail section.  The detail section is auto upper case
formatted.

.PARAMETER NoNewLine
If more data is needed later this helpfully stops CRLF from appending to the
string of text.  This is useful for waiting until a single step of a task
completes to the provide status confirmation to the output

.PARAMETER RightJustify
This will move the text to right side justification either on message for title
style or the detail for regular and header styles

.PARAMETER TrimPrefix
this will remove leading spaces and colon characters

.PARAMETER AddPrefix
This switch will enable prepending text before the message string text

.PARAMETER Prefix
This is the text to be prepended to the message text.  The default is current
time in the 24 Hour format.

.PARAMETER TrimSuffix
This removes trailing spaces and colon characters

.PARAMETER AddSuffix
This switch determines whether a suffix is added to the left section.

.PARAMETER Suffix
This is the additional text to append to the end of the left section.
The default is a colon and a space ': '

.PARAMETER ToTitleCase
This splits every word in the text and capitalizes each word

.PARAMETER TextPadding
this adjusts how to adjust and pad the left section of text

.PARAMETER LineLimit
Its 2021 and im still not certain if some CI/CD systems have an 80 character
limit or a 79 character limit.  The default is set to 80.

.EXAMPLE
Write-BuildOutput -Message "section details" -Detail "important details here" -ColorLeftSide 'DarkYellow' -ColorRightSide 'DarkGreen' -AddSuffix -AddPrefix -Title -RightJustify -ToTitleCase

This uses the Title format style which is only using the Message text and the
Detail is ignored.  Left color is DarkYellow and right color is ignored.  A
default suffix of ': ' is added and the default prefix of the current 24hr time
is prepended.  The Message value is right aligned to the default linelimit of
80 characters and all words are first letter capitalized

.NOTES
[System.ConsoleColor] Enumerator
===============================================================================
Black         0      The color black.
Blue          9      The color blue.
Cyan          11     The color cyan (blue-green).
DarkBlue      1      The color dark blue.
DarkCyan      3      The color dark cyan (dark blue-green).
DarkGray      8      The color dark gray.
DarkGreen     2      The color dark green.
DarkMagenta   5      The color dark magenta (dark purplish-red).
DarkRed       4      The color dark red.
DarkYellow    6      The color dark yellow (ochre).
Gray          7      The color gray.
Green         10     The color green.
Magenta       13     The color magenta (purplish-red).
Red           12     The color red.
White         15     The color white.
Yellow        14     The color yellow.

#>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [AllowEmptyString()]
        [string]
        $Message = [string]::Empty,

        [Parameter()]
        [string]
        $Detail = [string]::Empty,

        [ConsoleColor]
        $ColorLeftSide = [ConsoleColor]::Red,

        [ConsoleColor]
        $ColorRightSide = [ConsoleColor]::Red,

        [switch]
        $NoNewLine,

        # If not specified, then LeftJustify
        [switch]
        $RightJustify,

        [switch]
        $ToTitleCase,

        [int]
        $TextPadding = 0,

        [int]
        $LineLimit = 80
    )
    Begin {

    }
    Process {
        [scriptblock]$Prefix = { '[{0}] ERROR ' -f (Get-Date -UFormat %R) }
        Write-BuildOutput -Message $Message -Detail $Detail -ColorLeftSide $ColorLeftSide -ColorRightSide $ColorRightSide `
                          -NoNewLine:$NoNewLine -RightJustify:$RightJustify -ToTitleCase:$ToTitleCase -TextPadding $TextPadding `
                          -LineLimit $LineLimit -Title -TrimPrefix -AddPrefix -Prefix $Prefix -TrimSuffix -AddSuffix

    }
    End {
        throw ('{0} - {1}' -f $Message, $Detail)
    }
}
#Write-BuildError -Message Test -Detail 'Line 129' -RightJustify
