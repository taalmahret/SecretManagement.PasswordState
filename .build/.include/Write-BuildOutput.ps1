function Script:Write-BuildOutput {
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

.PARAMETER NoNewLine
This will insert a newline character after all text has been sent to the screen

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
# use only at maximum script scope in production pipelines
    [cmdletbinding()]
    [Diagnostics.CodeAnalysis.SuppressMessage("PSReviewUnusedParameter",'')]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [AllowEmptyString()]
        [string]
        $Message = [string]::Empty,

        [Parameter()]
        [string]
        $Detail = '',

        [ConsoleColor]
        $ColorLeftSide,

        [ConsoleColor]
        $ColorRightSide,

        [Switch]
        $Title,

        [switch]
        $Header,

        [switch]
        $NoNewLine,

        [switch]
        $ForceNewLine,

        # If not specified, then LeftJustify
        [switch]
        $RightJustify,

        [switch]
        $TrimPrefix,

        [switch]
        $AddPrefix,

        [scriptblock]
        $Prefix = { '[{0}] ' -f (Get-Date -UFormat %R) },

        [switch]
        $TrimSuffix,

        [switch]
        $AddSuffix,

        [string[]]
        $Suffix = ': ',

        [switch]
        $ToTitleCase,

        [switch]
        $ToSentenceCase,

        [int]
        $TextPadding = 35,

        [int]
        $LineLimit = 80
    )
    Begin {
        #region Functions

        class Message {
            [ConsoleColor]$Color = [ConsoleColor]::Gray
            [string]$Text = [string]::Empty
            [bool]$NoNewLine = $false

            # Hidden, helper method that the constructors must call.
            hidden Init([ConsoleColor]$Color,[string]$Text,[bool]$NoNewLine) {
                $this.Color = $Color
                $this.Text = $Text
                $this.NoNewLine = $NoNewLine
            }

            #Best way i can come up with a powershell chained constructor
            Message ([ConsoleColor]$Color,[string]$Text,[bool]$NoNewLine) {
                $this.Init($Color, $Text, $NoNewLine)
            }
            Message ([ConsoleColor]$Color,[string]$Text) {
                $this.Init($Color, $Text, $this.NoNewLine)
            }
            Message ([string]$Text) {
                $this.Init($this.Color, $Text, $this.NoNewLine)
            }
            Message () {
                $this.Init($this.Color, $this.Text, $this.NoNewLine)
            }

        }
        function Write-Color() {
            Param (
                [Message[]] $Message
            )
            begin {
                $startColor = $host.UI.RawUI.ForegroundColor;
            }
            process {
                foreach ($item in $Message) {
                    if (![string]::IsNullOrEmpty($item.Text) ) {
                        $host.UI.RawUI.ForegroundColor = $item.Color

                        #if ($Script:CursorPosition + $item.text.length -gt $Script:LineLimit) {
                        #Need to work this out so that the script doesnt run over linelimit
                        Write-Host $item.Text -NoNewline;
                        #}

                    }

                    if (-Not ($item.NoNewLine) ) {
                        Write-Host
                        $Script:CursorPosition = 0
                    }
                }
            }
            end {
                if ($ForceNewLine.IsPresent) {
                    Write-Host
                    $Script:CursorPosition = 0
                }

                $host.UI.RawUI.ForegroundColor = $startColor;
            }
        }

        function Build-Messages {
            [CmdletBinding()]
            param (
                [string]
                $Message,
                [string]
                $Detail,

                [System.ConsoleColor]
                $ColorL,
                [System.ConsoleColor]
                $ColorR,

                [bool]
                $NoNewLineMessage,
                [bool]
                $NoNewLineDetail

            )
            # Override colors if specified as a parameter to this cmdlet
            # Null coalescing going on here
            $ColorL = $ColorLeftSide ?? $ColorL ?? [System.ConsoleColor]::Gray
            $ColorR = $ColorRightSide ?? $ColorR ?? [System.ConsoleColor]::Gray

            $Messages = [System.Collections.ArrayList]@()
            if (![string]::IsNullOrEmpty($Message) ) {
                $Messages += [Message]::new($ColorL, $Message, $NoNewLineMessage)
            }
            if (![string]::IsNullOrEmpty($Detail) ) {
                $Messages += [Message]::new($ColorR, $Detail, $NoNewLineDetail)
            }

            $Messages

        }

        #endregion Functions

        #region Filters


        # these are specific use case based filters that just wont easily wirein to other functions
        # they are defined here to format the output functions text.  they also use local variables
        # that are not used by the script wide scope.  Left and Right justify are a mess... Sigh
        filter LeftJustify {
            [string]$Text = $_
            $PaddingLimit = switch ($Script:TextPadding) {
                { $_ -gt $Script:LineLimit} { $Script:LineLimit; break }
                { $_ -lt $Text.Length }        { $Text.Length; break }
                Default                     { $Script:TextPadding }
            }
            $Text.TrimStart(' ').PadRight($PaddingLimit,' ').Substring(0, $PaddingLimit)
        }
        filter RightJustify {
            $CursorPosition = $host.UI.RawUI.CursorPosition.X
            if ($Script:Message.Length -gt 0) { $CursorPosition = $Script:Message.Length }
            $LimitAdjust = $Script:LineLimit - $CursorPosition
            $_.PadLeft($Script:LineLimit,' ').substring($CursorPosition, $LimitAdjust)
        }

        filter AddPrefix {
            # If the input is slightly messy this hopefully gets it cleaned up again.
            (& $Prefix).ToString() + $_
        }

        filter AddSuffix {
            # If the input is slightly messy this hopefully gets it cleaned up again.
            $_ + $Suffix
        }

        filter FormatMessage {
            $Message = $_
            if (![string]::IsNullOrEmpty($Message) ) {
                $Message = if ( $ToTitleCase.IsPresent )    { $Message | Script:ToTitleCase    } else { $Message }
                $Message = if ( $ToSentenceCase.IsPresent ) { $Message | Script:ToSentenceCase } else { $Message }
                $Message = if ( $TrimPrefix.IsPresent )     { $Message | Script:TrimPrefix     } else { $Message }
                $Message = if ( $AddPrefix.IsPresent )      { $Message | AddPrefix             } else { $Message }
                $Message = if ( $TrimSuffix.IsPresent )     { $Message | Script:TrimSuffix     } else { $Message }
                $Message = if ( $AddSuffix.IsPresent )      { $Message | AddSuffix             } else { $Message }
                if ($Header.IsPresent) {
                    $Message = if ( $RightJustify.IsPresent ) { $Message | RightJustify        } else { $Message | LeftJustify }
                } else {
                    $Message = $Message | LeftJustify
                }

            } else {
                $Message = [string]::Empty
            }
            $Message
        }
        filter FormatDetail {
            $Detail = $_
            if (![string]::IsNullOrEmpty($Detail) ) {
                $Detail = if ( $RightJustify.IsPresent ) { $Detail | RightJustify } else { $Detail | LeftJustify }
            } else {
                $Detail = [string]::Empty
            }
            $Detail
        }
        #endregion Filters


        # I am having trouble with these being visible to the filters above
        $Script:CursorPosition = $host.UI.RawUI.CursorPosition.X
        $Script:LineLimit = $LineLimit
        $Script:TextPadding = $TextPadding
        $Script:Prefix = $Prefix

    }
    Process {

        if ($Title.IsPresent) { #Beginning Title Header Message
            $Script:Message = $Message | FormatMessage
            $Script:CursorPosition = $host.UI.RawUI.CursorPosition.X
            $Detail = $Detail | FormatDetail
            $ColorL = [ConsoleColor]::Cyan; $ColorR = [ConsoleColor]::Blue
            $Messages = Build-Messages -Message $Script:Message -Detail $Detail -ColorL $ColorL -ColorR $ColorR -NoNewLineMessage $true -NoNewLineDetail $NoNewLine.IsPresent
            Write-Color $Messages
        }

        if ($Header.IsPresent) { #Section Header Message
            $Script:Message = $Message | FormatMessage
            $Script:CursorPosition = $host.UI.RawUI.CursorPosition.X
            $Messages = Build-Messages -Message $Script:Message -Detail ([string]::Empty) -ColorL ([ConsoleColor]::Yellow) -NoNewLineMessage $NoNewLine.IsPresent
            Write-Color $Messages
        }

        #None of the switches present - Regular Message
        if ((-NOT $Title.IsPresent) -and (-NOT $Header.IsPresent )) {
            $Script:Message = $Message | FormatMessage
            $Script:CursorPosition = $host.UI.RawUI.CursorPosition.X
            $Detail = $Detail | FormatDetail
            $Messages = Build-Messages -Message $Script:Message -Detail $Detail -NoNewLineMessage $true -NoNewLineDetail $NoNewLine.IsPresent
            Write-Color $Messages
        }

    }
    End {
    }
}
#write-buildoutput -Message Text -Detail 'this import is done' -RightJustify
