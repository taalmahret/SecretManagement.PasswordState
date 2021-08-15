[CmdLetBinding()]
# global variables are only used for diagnostics and testing
# use only at maximum script scope in production pipelines
[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidGlobalVars, UseDeclaredVarsMoreThanAssignments",'')]
Param()

# These are small and quick definitions of filters and functions
# The purpose is to define functions that can stand alone and do
# not depend on any external references.

#region Functions & Filters

filter Script:ToTitleCase {
    $_.Split() | Select-Object @{Name='Text';Expression={ $_.substring(0,1).ToUpper() + $_.substring(1).ToLower() }} | Join-String -Property 'Text' -Separator ' '
}
filter Script:ToSentenceCase {
    $_.substring(0,1).ToUpper() + $_.substring(1).ToLower()
}
filter Script:TrimPrefix {
    # If the input is slightly messy this hopefully gets it cleaned up again.
    $_.TrimStart(" ").TrimStart(":").TrimStart(" ")
}
filter Script:TrimSuffix {
    # If the input is slightly messy this hopefully gets it cleaned up again.
    $_.TrimEnd(" ").TrimEnd(":").TrimEnd(" ")
}


#endregion Functions & Filters




# Update the class properties below to match your module build. These
# properties are initialized in variable BuildEnvironment and is then
# available to all functions during the build. The path root is assumed
# to be at the root of the PowerShell module project directory.

#region Module Classes

class BuildStatus {
    static [string]$Pass = '...PASS'
    static [string]$Fail = '...FAIL'
    static [string]$Warn = '...WARN'
    static [string]$Halt = '...HALT'
    static [string]$Done = '...DONE'
}

class BuildEnvironment {
    [string]$ProjectPath
    [string]$BuildToolFolder
    [string]$BuildToolPath
    [string]$BuildEnvironmentFile
    # Project website (used for external help cab file definition)
    [string]$ModuleWebsite
    [string]$ModuleRemoteRepo

    # The module we are building
    [string]$ProjectName
    [string]$ModulePath
    [string]$BuildIncludeFolder
    [string]$BuildIncludePath
    [string]$BuildRequirementsFile
    [System.Management.Automation.ErrorRecord]$BuildErrorRecord

    # Release directory. You typically want a module to reside in a folder of
    # the same name in order to publish to psgallery among other things.
    [string]$BaseReleaseFolder
    # Staging Area path - this is where all our scratch work occurs. It will be cleared out at every run.
    [string]$StagingAreaFolder
    [string]$BuildSystem
    [string]$BranchName
    # You really shouldn't change this for a powershell module (if you want it to publish to the psgallery correctly)
    [string]$CurrentReleaseFolder
    [string]$ScriptRoot
    [string]$StagingArea
    # Just before releasing the module we stage some changes in this location.
    [string]$StageReleasePath
    [string]$ReleasePath
    [string]$ReleaseNotes
    [string]$CurrentReleasePath
    # Used later to determine if we are in a configured state or not
    [bool]$IsConfigured
    [bool]$PSVersionValid
    # Used to update our function CBH to external help reference
    [string]$ExternalHelp

    # Load the current working build version from our module manifest
    [version]$ModuleVersion
    # These are required for a full build process and will be automatically installed if they aren't available
    [string[]]$RequiredModules
    # Put together our full paths. Generally leave these alone
    [string]$ModuleFullPath
    [string]$ModuleManifestFullPath


    # Hidden, helper method that the constructors must call.
    hidden [void] Init([string]$ProjectPath, [string]$BuildToolPath, [string]$ModuleWebsite, [string]$ModuleRemoteRepo) {
        $this.ProjectPath  =$ProjectPath

        $this.BuildToolFolder = '.build'
        $this.BuildIncludeFolder = '.include'
        $this.BuildToolPath = $BuildToolPath
        $this.BuildEnvironmentFile = (Join-Path $BuildToolPath '.buildenvironment.ps1') # without this, nothing will run
        $this.BuildIncludePath = (Join-Path $BuildToolPath $this.BuildIncludeFolder)
        $this.BuildRequirementsFile = (Join-Path $ProjectPath 'requirements.psd1')

        $this.ProjectName = Split-Path ($ProjectPath) -Leaf
        $this.ModulePath = Join-Path -Path $ProjectPath -ChildPath $this.ProjectName
        $this.BaseReleaseFolder = '.release'
        $this.StagingAreaFolder = '.temp'
        $this.BuildSystem = 'GitHub Actions'
        $this.BranchName = 'main'
        $this.CurrentReleaseFolder = $this.ProjectName
        $this.StagingArea = Join-Path $ProjectPath $this.StagingAreaFolder
        $this.StageReleasePath = Join-Path $this.StagingArea $this.BaseReleaseFolder
        $this.ReleasePath = Join-Path $ProjectPath $this.BaseReleaseFolder
        $this.CurrentReleasePath = Join-Path $this.ReleasePath $this.CurrentReleaseFolder

        $this.ModuleWebsite = $ModuleWebsite
        $this.ModuleRemoteRepo = $ModuleRemoteRepo

        $this.ExternalHelp = "<#" + [System.Environment]::NewLine
        $this.ExternalHelp += "    .EXTERNALHELP $($this.ProjectName)-help.xml" + [System.Environment]::NewLine
        $this.ExternalHelp += "#>" + [System.Environment]::NewLine

        $this.IsConfigured = $False

        $this.InitReadOnlyProperties()
        $this.InitBuildEnvironment()
    }

    hidden [void] InitReadOnlyProperties() {
        Add-Member -InputObject $this -MemberType ScriptProperty -Force -Name 'ModuleVersion' -Value { return (Test-ModuleManifest $this.ModuleManifestFullPath | Select-Object -ExpandProperty Version) }
        Add-Member -InputObject $this -MemberType ScriptProperty -Force -Name 'RequiredModules' -Value { return [string[]]@(((Import-PowerShellDataFile -Path $this.BuildRequirementsFile).keys) -notmatch 'PSDependOptions') }
        Add-Member -InputObject $this -MemberType ScriptProperty -Force -Name 'ModuleFullPath' -Value { return (Get-Item (Join-Path -Path $this.ModulePath -ChildPath "$($this.ProjectName).psm1")).FullName }
        Add-Member -InputObject $this -MemberType ScriptProperty -Force -Name 'ModuleManifestFullPath' -Value { return (Get-Item (Join-Path -Path $this.ModulePath -ChildPath "$($this.ProjectName).psd1")).FullName }
        Add-Member -InputObject $this -MemberType ScriptProperty -Force -Name 'PSVersionValid' -Value { return ($PSVersionTable.PSVersion.Major.ToString() -ge '7') }
    }

    hidden [void] InitBuildEnvironment() {
        Get-ChildItem $this.BuildIncludePath -Recurse -Filter "*.ps1" -File -Include '*-Build*' | ForEach-Object {
            $File = $_.FullName
            # Either the file loads or it doesnt.  These are the raw build files needed though, so good luck!
            try { . $File } catch { throw('Failed to load initial build helper scripts {0}!' -f $File) }
        } #this will enable buildoutput and erroroutput

        # Dot source any build script functions we need to use
        Write-BuildOutput -Message 'Loading Build Environment' -Header -ToTitleCase -AddPrefix -TextPadding 80
        Write-BuildOutput -Message "Initializing Task" -Detail "Load Build Environment" -Title -TextPadding 0 -AddSuffix -ForceNewLine
        Write-BuildOutput -Message 'Searching for build tools...' -NoNewLine -TextPadding 0
        $BuildTools = Get-ChildItem $this.BuildIncludePath -Recurse -Filter "*.ps1" -File
        if ($BuildTools.Count -gt 0) {
            Write-BuildOutput -Message ('Tools Found: {0}' -f $BuildTools.Count) -NoNewLine
            Write-BuildOutput -Detail ([BuildStatus]::Pass) -RightJustify -ColorRightSide DarkGreen
        } else {
            Write-BuildOutput -Detail ([BuildStatus]::Fail) -RightJustify -ColorRightSide Red
            Write-BuildError -Message 'Unable to load build environment'
        }

        $BuildTools | ForEach-Object {
            try {
                Write-BuildOutput -Message "Loading $($_.Name) script" -NoNewLine -TextPadding 70
                . $_.FullName
                Write-BuildOutput -Detail ([BuildStatus]::Pass) -RightJustify -ColorRightSide DarkGreen
            }
            catch {
                Write-BuildOutput -Detail ([BuildStatus]::Fail) -RightJustify -ColorRightSide Red
            }

        }

        Write-BuildOutput -ForceNewLine
        Write-BuildOutput -Message "Finalizing Task" -Detail "Load Build Tools" -Title -TextPadding 0 -AddSuffix -ForceNewLine

    }

    [void] Bootstrap() {

        Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        $RequirementsFilename = (Split-Path -Path $this.BuildRequirementsFile -Leaf -ErrorAction SilentlyContinue) ?? 'Unknown Filename'

        Write-BuildOutput -Message "Initializing Task" -Detail "PSDepend" -Title -TextPadding 0 -AddSuffix -ForceNewLine
        Write-BuildOutput -Message 'Searching for configuration file' -NoNewLine -AddSuffix
        Write-BuildOutput -Message $RequirementsFilename -NoNewLine -ToSentenceCase

        if ((Test-Path -Path $this.BuildRequirementsFile)) {
            Write-BuildOutput -Detail ([BuildStatus]::Pass) -RightJustify -ColorRightSide DarkGreen
            if (-not (Get-Module -Name PSDepend -ListAvailable)) {
                Write-BuildOutput -Message "Installing Module PSDepend" -NoNewLine
                $null = Install-Module -Name PSDepend -Repository PSGallery -Scope CurrentUser -Force
                Write-BuildOutput -Detail ([BuildStatus]::Done) -RightJustify -ColorRightSide DarkGreen
            }
            Write-BuildOutput -Message "Importing Module PSDepend" -NoNewLine
            Import-Module -Name PSDepend -Verbose:$false
            Write-BuildOutput -Detail ([BuildStatus]::Done) -RightJustify -ColorRightSide DarkGreen

            Write-BuildOutput -Message "Installing Dependency Modules" -NoNewLine
            Invoke-PSDepend -Path $this.BuildRequirementsFile -Install -Import -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable $this.BuildErrorRecord

            if ($this.BuildErrorRecord.count -gt 0) {
                Write-BuildOutput -Detail ([BuildStatus]::Warn) -RightJustify -ColorRightSide Yellow
                Write-BuildOutput -Message "Install Dependency Modules Warnings" -Header -AddSuffix -AddPrefix

                foreach ($Err in $this.BuildErrorRecord) {
                    $FileCI = ($Err.InvocationInfo.ScriptName).ToLower() #Case Insensative Search
                    $File= $Err.InvocationInfo.ScriptName
                    $ErrModuleName = $File.Substring(($FileCI.IndexOf('\modules\') + 9)) | ForEach-Object { $_.Substring(0,$_.IndexOf('\')) }
                    if ([string]::IsNullOrEmpty($ErrModuleName) ) { $ErrModuleName = $err.TargetObject }
                    if ([string]::IsNullOrEmpty($ErrModuleName) ) { $ErrModuleName = 'Unknown Error Source' }

                    $Version = Split-Path $File -ErrorAction SilentlyContinue | Select-String '((?:\d{1,3}\.){1,4}\d{1,3})' | ForEach-Object {
                        $_.Matches[0].Groups[1].Value
                    }
                    $Version ??= '0.0.0'
                    $ErrorName = $Err.FullyQualifiedErrorId.Split(",")[0]
                    Write-BuildOutput -Message $ErrorName -Detail ('{0} - {1}' -f $ErrModuleName, $Version) -Title -RightJustify -ColorLeftSide Gray -ColorRightSide Gray

                }
            } else {
                Write-BuildOutput -Detail ([BuildStatus]::Done) -RightJustify -ColorRightSide DarkGreen
            }
        } else {
            Write-BuildOutput -Detail ([BuildStatus]::Halt) -RightJustify -ColorRightSide Red
            throw ('The file "{0}" is missing!' -f $this.BuildRequirementsFile)
        }
        Write-BuildOutput -ForceNewLine
        Write-BuildOutput -Message "Finalizing Task" -Detail "PSDepend" -Title -TextPadding 0 -AddSuffix -ForceNewLine

    }

    #Best way i can come up with a powershell chained constructor
    BuildEnvironment ([string]$ProjectPath, [string]$BuildToolPath, [string]$ModuleWebsite, [string]$ModuleRemoteRepo) {
        $this.Init($ProjectPath, $BuildToolPath, $ModuleWebsite, $ModuleRemoteRepo)
    }
    BuildEnvironment ([string]$ProjectPath, [string]$BuildToolPath) {
        $this.Init($ProjectPath, $BuildToolPath, ($Script:ModuleWebsite), ($Script:ModuleRemoteRepo))
    }
    BuildEnvironment ([string]$ProjectPath) {
        $this.Init($ProjectPath, ($Script:BuildToolPath), ($Script:ModuleWebsite), ($Script:ModuleRemoteRepo))
    }
    #This one does not seem safe.  Use at your own risk.
    BuildEnvironment () {
        $this.Init($PSScriptRoot, ($Script:BuildToolPath), ($Script:ModuleWebsite), ($Script:ModuleRemoteRepo))
    }

    [string] GetRepoData() {
        try {
            $branch = git rev-parse --abbrev-ref HEAD
            $Ref = "refs/heads/$branch"

            $gitHist = (git log --format="%ai`t%H`t%an`t%ae`t%s" -n 100) | ConvertFrom-Csv -Delimiter "`t" -Header ("Date","CommitId","Author","Email","Subject")

            if ($branch -eq "HEAD") {
                # we're probably in detached HEAD state, so print the SHA
                $branch = git rev-parse --short HEAD
                return " ($branch)" #-ForegroundColor "red"
            }
            else {
                # we're on an actual branch, so print it
                return " ($branch)" #-ForegroundColor "blue"
            }
        } catch {
            # we'll end up here if we're in a newly initiated git repo
            return " (no branches yet)" #-ForegroundColor "yellow"
        }
    }

}

#endregion Module Classes




# A terrible rumbling begins in the depths of the deep...Global ONLY for testing please.
$Global:BuildEnvironment = [BuildEnvironment]::New($ProjectPath, $BuildToolPath, $ModuleWebsite)
