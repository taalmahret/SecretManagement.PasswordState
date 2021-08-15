<#
.SYNOPSIS
Powershell Script module vault extension

.DESCRIPTION
The functions in this module are the implementation to interop
with powershell secret management.

.NOTES
ModuleName    : SecretManagement.PasswordState
Created by    : David Tawater
Date Coded    : 2021-07-29

.LINK
https://github.com/taalmahret/SecretManagement.PasswordState

.LINK
https://github.com/PowerShell/SecretManagement
#>

#Grab the initialization script and then dot source first

$BHProjectExtensionName = '{0}.Extension' -f $env:BHProjectName
$ExtensionModuleRoot = Join-Path -Path $PSScriptRoot -ChildPath $BHProjectExtensionName
write-host ('PSScriptRoot: {0}' -f $PSScriptRoot)
write-host ('ExtensionModuleRoot: {0}' -f $ExtensionModuleRoot)

$private = @(Get-ChildItem -Path (Join-Path -Path $ExtensionModuleRoot -ChildPath 'Private/Initialize-Module.ps1') -ErrorAction Stop)
try {
    . $private.FullName
} catch {
    throw "Unable to dot source Initialization script [$($private.FullName)]"
}

# Dot source classes and public/private functions
$classes = @(Get-ChildItem -Path (Join-Path -Path $ExtensionModuleRoot -ChildPath 'Classes/*.ps1') -Recurse -ErrorAction Stop)
$public  = @(Get-ChildItem -Path (Join-Path -Path $ExtensionModuleRoot -ChildPath 'Public/*.ps1')  -Recurse -ErrorAction Stop)
#Grab everything but the initialization script as its already dot sourced
$private = @(Get-ChildItem -Path (Join-Path -Path $ExtensionModuleRoot -ChildPath 'Private/*.ps1') -Exclude 'Private/Initialize-Module.ps1' -Recurse -ErrorAction Stop)
foreach ($import in @($classes + $private + $public)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]"
    }
}

Export-ModuleMember -Function $public.Basename
