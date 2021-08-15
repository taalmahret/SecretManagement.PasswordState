<#
    .SYNOPSIS
        Performs initial module tasks and configurations
    .DESCRIPTION
        This is the landing script for the entry point of this module
    .EXAMPLE
        .\Initialize-Module.ps1

        this is automatically called from the build task in the main module folder
    .NOTES
        This function has not been updated yet.
#>
[CmdletBinding()]
param (

)

[bool]$7zEXE = $false
[bool]$7zSFX = $false
$ScriptFilePath = $MyInvocation.MyCommand.Path
$ScriptPath = Split-Path $ScriptFilePath

#See if 7zip is installed otherwise use the script directory
try {
    $P = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\7z*').GetValue("Path")
} catch {
    #If an alternate path is given lets use that.  If not lets try to use the current script running command path.
    $P = if ( [string]::IsNullOrEmpty($AlternatePath) ) { $ScriptPath } else { $AlternatePath }
} finally {
    $7z = Join-Path $P -ChildPath "7z.exe"
    if (Test-Path -PathType Leaf $7z) { [string]$7zEXE = $7z }

    $7za = Join-Path $P -ChildPath "7za.exe"
    if (Test-Path -PathType Leaf $7za) { [string]$7zEXE = $7za }

    $7fx = Join-Path $P -ChildPath "7z.sfx"
    if (Test-Path -PathType Leaf $7fx) { [string]$7zSFX = $7fx }
}

if ($false -eq $7zEXE) {
    $Output = ('Locations Searched: {0}7z.exe: {1}{0}7za.exe: {2}' -f "`r`n", $7z, $7za)
    #throw ('7-zip not installed or in path. This file is required for all operations of this module{0}{1}' -f "`r`n", $Output)
}

$7zSettings = [ordered]@{
    Path7zEXE       = $7zEXE
    Path7zSFX       = $7zSFX
    ScriptDirectory = if ($null -ne $ScriptPath) { Split-Path -Path $ScriptPath -Parent } else { (Get-Location) }
    ScriptFilePath  = if ($null -ne $ScriptPath) { Split-Path -Path $ScriptPath } else { Join-Path -Path (Get-Location) -ChildPath 'UnknownScriptFileName.ps1' }
}
New-Variable -Name 7zSettings -Value $7zSettings -Scope Script -Force
