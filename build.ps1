[CmdletBinding(DefaultParameterSetName='Task')]
param(
    # Build task(s) to execute
    [parameter(Position = 0)]
    [Alias('Task')]
    [string[]]$BuildTask = 'default',

    # Bootstrap dependencies
    [switch]$Bootstrap,

    # Increment Version of Project
    [switch]$IncrementMajorVersion,
    [switch]$IncrementMinorVersion
)

# The main project build tool path folders
$Script:ProjectPath = $PSScriptRoot
$Script:BuildToolFolder = '.build'
$Script:BuildToolPath = Join-Path $ProjectPath $BuildToolFolder # Additional build scripts and tools are found here
$Script:BuildEnvironmentFile = (Join-Path $BuildToolPath '.buildenvironment.ps1') # without this, nothing will run
$Script:ModuleWebsite = 'https://github.com/taalmahret/SecretManagement.PasswordState'
$Script:ModuleRemoteRepo = 'git://github.com/taalmahret/SecretManagement.PasswordState.git'
$BuildTask = $BuildTask | ForEach-Object { if ($_ -eq 'default') { '.' } else { $_ } }

#Do we even have the basics to load this build environment?
if (-Not (Test-Path $BuildEnvironmentFile ) ) { throw("Build Environment File Not Found!") }
. $BuildEnvironmentFile

# Bootstrap module dependencies
if ($Bootstrap.IsPresent) { $BuildEnvironment.Bootstrap()}

Write-BuildOutput -Message "Build Task Parameters" -Detail ($BuildTask | Join-String -Separator ', ') -Title -TextPadding 0 -AddSuffix -ForceNewLine
return
# Kick off the standard build
try {
    Invoke-Build -Task $BuildTask
}
catch {
    # If it fails then show the error and try to clean up the environment
    Write-BuildOutput -Message 'Build Failed with the following error:' -Header -ToTitleCase -AddPrefix -ColorLeftSide Red -TextPadding 80
    Write-Error $_
}
finally {
    Write-BuildOutput -ForceNewLine
    Write-BuildOutput -Message 'Build Session cleanup' -ToTitleCase -AddPrefix -AddSuffix -NoNewLine
    Invoke-Build BuildSessionCleanup
    $null = Remove-Module InvokeBuild
    Write-BuildOutput -Detail "...Done" -RightJustify -ColorRightSide DarkGreen

}
