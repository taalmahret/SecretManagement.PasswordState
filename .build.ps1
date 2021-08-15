param (
	[string]$ReleaseNotes = $null
)



#Synopsis: Validate system requirements are met
task ValidateRequirements {
    #Write-Host -NoNewLine '      Running Powershell version 5?'
    #assert ($PSVersionTable.PSVersion.Major.ToString() -eq '5') 'Powershell 5 is required for this build to function properly (you can comment this assert out if you are able to work around this requirement)'
    #Write-Host -ForegroundColor Green '...Yup!'
}

#Synopsis: Load required modules if available. Otherwise try to install, then load it.
task LoadRequiredModules {
    $BuildEnvironment.RequiredModules | ForEach-Object {
        Write-BuildOutput -Message "Verifying $($_) Module" -NoNewLine -TextPadding 70
        if ($null -eq (get-module $_ -ListAvailable) ) {
            $null = Install-Module $_
            Write-BuildOutput -Detail "...Installed!" -RightJustify -ColorRightSide DarkYellow
        } else {
            Write-BuildOutput -Detail "...Done" -RightJustify -ColorRightSide DarkGreen
        }

        Write-BuildOutput -Message "Importing $($_) Module" -NoNewLine -TextPadding 70
        if (get-module $_ -ListAvailable) {
            $null = Import-Module $_ -Force
            Write-BuildOutput -Detail "...Done" -RightJustify -ColorRightSide DarkGreen
        }
        else {
            Write-BuildOutput -Detail "...Failed!" -RightJustify -ColorRightSide Red
            throw ("Failed to import $($_) module")
        }
    }




}

#Synopsis: Load dot sourced functions into this build session
task LoadBuildTools {

}

# Synopsis: Import the current module manifest file for processing
task LoadModuleManifest {
    assert (test-path $ModuleManifestFullPath) "Unable to locate the module manifest file: $ModuleManifestFullPath"

    Write-Host -NoNewLine '      Loading the existing module manifest for this module'
    $Script:Manifest = Import-PowerShellDataFile -Path $ModuleManifestFullPath

    # Validate we have a rootmodule defined
    if(-not $Script:Manifest.RootModule) {
        $Script:Manifest.RootModule = $Manifest.ModuleToProcess
        # If we don't then name it after the module to build
        if(-not $Script:Manifest.RootModule) {
            $Script:Manifest.RootModule = "$ProjectName.psm1"
        }
    }

    # Store this for later
    $Script:ReleaseModule = Join-Path $StageReleasePath $Script:Manifest.RootModule
    Write-Host -ForegroundColor Green '...Loaded!'
}

# Synopsis: Create new module manifest
task CreateModuleManifest -After CreateModulePSM1 {
    Write-Host -NoNewLine '      Attempting to create a new module manifest file at .'
    $Script:Manifest.ModuleVersion = $Script:Version
    $Script:Manifest.FunctionsToExport = $Script:FunctionsToExport
    $Script:Manifest.CmdletsToExport = $Script:Module.ExportedCmdlets.Keys
    $Script:Manifest.VariablesToExport = $Script:Module.ExportedVariables.Keys
    $Script:Manifest.AliasesToExport = $Script:Module.ExportedAliases.Keys
    $Script:Manifest.WorkflowsToExport = $Script:Module.ExportedWorkflows.Keys
    $Script:Manifest.DscResourcesToExport = $Script:Module.ExportedDscResources.Keys
    $Script:Manifest.FormatFilesToExport = $Script:Module.ExportedFormatFiles.Keys
    $Script:Manifest.TypeFilesToExport = $Script:Module.ExportedTypeFiles.Keys

    # Update the private data element so it will work properly with new-modulemanifest
    $tempPSData = $Script:Manifest.PrivateData.PSdata

    if ( $tempPSData.Keys -contains 'Tags') {
        $tempPSData.Tags = @($tempPSData.Tags | ForEach-Object {$_})
    }
    $NewPrivateDataString = "PrivateData = @{`r`n"
    $NewPrivateDataString += '  PSData = '
    $NewPrivateDataString += (Convert-HashToString $tempPSData)
    $NewPrivateDataString +=  "`r`n}"

    # We do this because private data never seems to give the results I want in the manifest file
    # Later we replace the whole string in the manifest with what we want.
    $Script:Manifest.PrivateData = ''

    # Remove some hash elements which cannot be passed to new-modulemanifest
    if ($Script:Manifest.Keys -contains 'TypeFilesToExport') {
        $Script:Manifest.Remove('TypeFilesToExport')
    }
    if ($Script:Manifest.Keys -contains 'WorkflowsToExport') {
        $Script:Manifest.Remove('WorkflowsToExport')
    }
    if ($Script:Manifest.Keys -contains 'FormatFilesToExport') {
        $Script:Manifest.Remove('FormatFilesToExport')
    }
    $MyManifest = $Script:Manifest
    New-ModuleManifest @MyManifest -Path $StageReleasePath\$ProjectName.psd1

    # Replace the whole private data section with our own string instead
    Replace-FileString -Pattern "PrivateData = ''"  $NewPrivateDataString $StageReleasePath\$ProjectName.psd1 -Overwrite -Encoding 'UTF8'
}

# Synopsis: Load the module project
task LoadModule {
    Write-Host -NoNewLine '      Attempting to load the project module.'
    try {
        $Script:Module = Import-Module $ModuleManifestFullPath -Force -PassThru
        Write-Host -ForegroundColor Green '...Loaded!'
    }
    catch {
        throw "Unable to load the project module: $($ModuleFullPath)"
    }
}

# Synopsis: Set $script:Version.
task Version {
    #we'll need to come up with a better way of declaring our release versions
    $Script:Version = [version](Test-ModuleManifest $ModuleManifestFullPath | Select-Object -ExpandProperty Version)

    Write-Host -NoNewLine '      Manifest version and the release version are the same?'
    assert ( ($Script:Module).Version.ToString() -eq (($Script:Version).ToString())) "The module manifest version ($(($Script:Module).Version.ToString())) and release version ($($Script:Version)) are mismatched. These must be the same before continuing. Consider running the UpdateVersion task to make the module manifest version the same as the release version."
    Write-Host -ForegroundColor Green '...Yup!'
}

#Synopsis: Validate script requirements are met, load required modules, load project manifest and module, and load additional build tools.
task Configure ValidateRequirements, LoadRequiredModules, LoadModuleManifest, LoadModule, Version, LoadBuildTools, {
    # If we made it this far then we are configured!
    $Script:IsConfigured = $True
    Write-Host -NoNewline '      Configure build environment'
    Write-Host -ForegroundColor Green '...configured!'
}

# Synopsis: Update current module manifest with the version defined in version.txt if they differ
task UpdateVersion LoadBuildTools, LoadModuleManifest, LoadModule, Version, {
    assert ($null -ne $Script:Version) 'Unable to pull a version from version.txt!'
    if (error Version) {
        $ModVer = .{switch -Regex -File $ModuleManifestFullPath {"ModuleVersion\s+=\s+'(\d+\.\d+\.\d+)'" {return $Matches[1]}}}
        if ($ModVer -ne $null) {
            Write-Host -NoNewline "      Attempting to update the module manifest version ($ModVer) to $(($Script:Version).ToString())"
            $NewManifestVersion = "ModuleVersion = '" + $Script:Version + "'"
            Replace-FileString -Pattern "ModuleVersion\s+=\s+'\d+\.\d+\.\d+'" $NewManifestVersion $ModuleManifestFullPath -Overwrite
            Write-Host -ForegroundColor Green '...Updated!'
        }
        else {
            throw 'The module manifest file does not seem to contain a ModuleVersion directive!'
        }
    }
    else {
        Write-Output '      Module manifest version and version found in version.txt are already the same.'
    }
}


# Synopsis: IncrementVersion - Set increment build if any compatible tasks are initialized
task IncrementVersion {


    if ( -Not ($IncrementBuildVersion.IsPresent) ) { [switch]$IncrementBuildVersion = ($Task -in @('Build','Test','Publish', 'Default')) }
    $IncrementVersion = ($IncrementMajorVersion.IsPresent -or $IncrementMinorVersion.IsPresent -or $IncrementBuildVersion.IsPresent)
    #Write-ShellMessage -Message 'IncrementVersion' -Detail ($IncrementVersion -eq $true).ToString()
    Write-Build Gray 'Green message'
    Write-Build
    if ($IncrementVersion) {
        Set-BuildEnvironment -Force
        $CurrentVersion = Test-ModuleManifest $ENV:BHPSModuleManifest | Select-Object -ExpandProperty Version
        $Build = $CurrentVersion.Build
        $Minor = $CurrentVersion.Minor
        $Major = $CurrentVersion.Major

        if ($IncrementMajorVersion) { $Major++;$Minor=0;$Build=-1 }
        if ($IncrementMinorVersion) { $Minor++;$Build=-1 }
        #While the switch is nice....build is always updated when this test is performed
        $Build++

        $NewVersion = [System.Version]$("{0}.{1}.{2}" -f $Major,$Minor,$Build)
        Update-ModuleManifest -Path $ENV:BHPSModuleManifest -ModuleVersion $NewVersion
        Write-ShellMessage -Message 'Increment Version' -Header
        Write-ShellMessage -Message 'Major Version Changed' -Detail $IncrementMajorVersion.ToString()
        Write-ShellMessage -Message 'Minor Version Changed' -Detail $IncrementMinorVersion.ToString()
        Write-ShellMessage -Message 'Build Version Changed' -Detail $IncrementBuildVersion.ToString()
        Write-ShellMessage -Message 'New Version Number' -Detail $NewVersion.ToString()

    }
}

# Synopsis: Remove/regenerate scratch staging directory
task Clean {
	$null = Remove-Item $StagingArea -Force -Recurse -ErrorAction 0
    $null = New-Item $StagingArea -ItemType:Directory
    Write-Host -NoNewLine "      Clean up our scratch/staging directory at $($StagingArea)"
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Create base content tree in scratch staging area
task PrepareStage {
    # Create the directories
    $null = New-Item "$($StagingArea)\src" -ItemType:Directory -Force
    $null = New-Item $StageReleasePath -ItemType:Directory -Force
    filter rebase($from=($pwd.Path), $to)  {
        $_ -Replace [regex]::Escape($from), $to
    }

    # Copy main module data files
    Get-Item -Path (Join-Path -Path $ModulePath -ChildPath '*') -Include @('*.psm1', '*.psd1') | Copy-Item -Destination $StagingArea


    $PublicFiles = Get-ChildItem -Path $ModulePath -Include @('*.ps1') -Recurse | Where-Object FullName -Like '*\Public\*' | ForEach-Object {
        $SourceFile  = $_.FullName
        $Destination = $_.FullName.Replace($_.Name, '') | rebase -from $modulepath -to $StagingArea

        if (-Not (Test-Path -Path $Destination)) { New-Item -Path $Destination -ItemType Directory -Force }

        Copy-Item -Path $SourceFile -Destination $Destination
    }


    Copy-Item -Path "$($ScriptRoot)\$($PublicFunctionSource)" -Recurse -Destination "$($StagingArea)\$($PublicFunctionSource)"
    Copy-Item -Path "$($ScriptRoot)\$($PrivateFunctionSource)" -Recurse -Destination "$($StagingArea)\$($PrivateFunctionSource)"
    Copy-Item -Path "$($ScriptRoot)\$($OtherModuleSource)" -Recurse -Destination "$($StagingArea)\$($OtherModuleSource)"
    Copy-Item -Path "$($ScriptRoot)\en-US" -Recurse -Destination $StagingArea
}, GetPublicFunctions

# Synopsis:  Collect a list of our public methods for later module manifest updates
task GetPublicFunctions {
    $Exported = @()
    Get-ChildItem "$($ScriptRoot)\$($PublicFunctionSource)" -Recurse -Filter "*.ps1" -File | Sort-Object Name | ForEach-Object {
       $Exported += ([System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $_.FullName -Raw), [ref]$null, [ref]$null)).FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object {$_.Name}
    }
    # $Script:FunctionsToExport = (Get-ChildItem -Path $ScriptRoot\$($PublicFunctionSource)).BaseName | foreach {$_.ToString()}
    $Script:FunctionsToExport = $Exported
    Write-Host -NoNewLine '      Parsing for public (exported) function names'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Assemble the module for release
task CreateModulePSM1 {
    $CombineFiles = "## OTHER MODULE FUNCTIONS AND DATA ##`r`n`r`n"
    Write-Host "      Other Source Files: $($StagingArea)\$($OtherModuleSource)"
    Get-childitem  (Join-Path $StagingArea "$($OtherModuleSource)\*.ps1") | ForEach-Object {
        Write-Host "             $($_.Name)"
        $CombineFiles += (Get-content $_ -Raw) + "`r`n`r`n"
    }
    Write-Host -NoNewLine "      Combining other source files"
    Write-Host -ForegroundColor Green '...Complete!'

    $CombineFiles += "## PRIVATE MODULE FUNCTIONS AND DATA ##`r`n`r`n"
    Write-Host  "      Private Source Files: $($StagingArea)\$($PrivateFunctionSource)"
    Get-childitem  (Join-Path $StagingArea "$($PrivateFunctionSource)\*.ps1") | ForEach-Object {
        Write-Host "             $($_.Name)"
        $CombineFiles += (Get-content $_ -Raw) + "`r`n`r`n"
    }
    Write-Host -NoNewLine "      Combining private source files"
    Write-Host -ForegroundColor Green '...Complete!'

    $CombineFiles += "## PUBLIC MODULE FUNCTIONS AND DATA ##`r`n`r`n"
    Write-Host  "      Public Source Files: $($PublicFunctionSource)"
    Get-childitem  (Join-Path $StagingArea "$($PublicFunctionSource)\*.ps1") | ForEach-Object {
        Write-Host "             $($_.Name)"
        $CombineFiles += (Get-content $_ -Raw) + "`r`n`r`n"
    }
    Write-Host -NoNewline "      Combining public source files"
    Write-Host -ForegroundColor Green '...Complete!'

    Set-Content $Script:ReleaseModule ($CombineFiles) -Encoding UTF8
    Write-Host -NoNewLine '      Combining module functions and data into one PSM1 file'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Copy over the source and psm module without modification
task CopyModulePSM1 {
    Copy-Item -Path (Join-Path $StagingArea "$($OtherModuleSource)\*.ps1") -Recurse -Destination $StageReleasePath -Force
    Copy-Item -Path (Join-Path $StagingArea "$($PrivateFunctionSource)\*.ps1") -Recurse -Destination $StageReleasePath -Force
    Copy-Item -Path (Join-Path $StagingArea "$($PublicFunctionSource)\*.ps1") -Recurse -Destination $StageReleasePath -Force
    Copy-Item -Path (Join-Path $StagingArea "$($ProjectName).psm1") -Destination $StageReleasePath -Force
    Write-Host -NoNewLine '      Copy over source and psm1 files'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Warn about not empty git status if .git exists.
task GitStatus -If (Test-Path .git) {
	$status = exec { git status -s }
	if ($status) {
		Write-Warning "      Git status: $($status -join ', ')"
	}
}

# Synopsis: Run code formatter against our working build (dogfood).
task FormatCode {
        Get-ChildItem -Path $StagingArea -Include "*.ps1","*.psm1" -Recurse -File | Where-Object {$_.FullName -notlike "$($StageReleasePath)*"} | ForEach-Object {
            $FormattedOutFile = $_.FullName
            Write-Output "      Formatting File: $($FormattedOutFile)"
            $FormattedCode = get-content $_ -raw |
                Format-ScriptRemoveStatementSeparators |
                Format-ScriptExpandFunctionBlocks |
                Format-ScriptExpandNamedBlocks |
                Format-ScriptExpandParameterBlocks |
                Format-ScriptExpandStatementBlocks |
                Format-ScriptPadOperators |
                Format-ScriptPadExpressions |
                Format-ScriptFormatTypeNames |
                Format-ScriptReduceLineLength |
                Format-ScriptRemoveSuperfluousSpaces |
                Format-ScriptFormatCodeIndentation

                $FormattedCode | Out-File -FilePath $FormattedOutFile -force -Encoding:utf8
        }
        Write-Host ''
        Write-Host -NoNewLine '      Reformat script files'
        Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Replace comment based help with external help in all public functions for this project
task UpdateCBH -Before CreateModulePSM1 {
    $CBHPattern = "(?ms)(\<#.*\.SYNOPSIS.*?#>)"
    Get-ChildItem -Path "$($StagingArea)\$($PublicFunctionSource)\*.ps1" -File | ForEach-Object {
            $FormattedOutFile = $_.FullName
            Write-Output "      Replacing CBH in file: $($FormattedOutFile)"
            $UpdatedFile = (get-content  $FormattedOutFile -raw) -replace $CBHPattern, $ExternalHelp
            $UpdatedFile | Out-File -FilePath $FormattedOutFile -force -Encoding:utf8
    }
}

# Synopsis: Run PSScriptAnalyzer against the assembled module
task AnalyzeScript -After CreateModulePSM1 {
    $Analysis = Invoke-ScriptAnalyzer -Path $StageReleasePath
    $AnalysisErrors = @($Analysis | Where-Object {@('Information','Warning') -notcontains $_.Severity})

    if ($AnalysisErrors.Count -ne 0) {
        throw 'Script Analysis came up with some errors!'
    }

    Write-Host -NoNewLine '      Analyzing script module'
    Write-Host -ForegroundColor Green '...Complete!'
    $AnalysisWarnings = @($Analysis | Where-Object {$_.Severity -eq 'Warning'})
    $AnalysisInfo =  @($Analysis | Where-Object {$_.Severity -eq 'Information'})
    Write-Host -ForegroundColor Yellow "          Script Analysis Warnings = $($AnalysisWarnings.Count)"
    Write-Host "          Script Analysis Informational = $($AnalysisInfo.Count)"
}

# Synopsis: Build help files for module
task CreateHelp CreateMarkdownHelp, CreateExternalHelp, CreateUpdateableHelpCAB, {
    Write-Host -NoNewLine '      Create help files'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Build help files for module and ignore missing section errors
task TestCreateHelp Configure, CreateMarkdownHelp, CreateExternalHelp, CreateUpdateableHelpCAB,  {
    Write-Host -NoNewLine '      Create help files'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Build the markdown help files with PlatyPS
task CreateMarkdownHelp GetPublicFunctions, {
    # First copy over documentation
    Copy-Item -Path "$($StagingArea)\en-US" -Recurse -Destination $StageReleasePath -Force

    $OnlineModuleLocation = "$($ModuleWebsite)/$($BaseReleaseFolder)"
    $FwLink = "$($OnlineModuleLocation)/$($CurrentReleaseFolder)/docs/$($ProjectName).md"
    $ModulePage = "$($StageReleasePath)\docs\$($ProjectName).md"

    # Create the .md files and the generic module page md as well
    $null = New-MarkdownHelp -module $ProjectName -OutputFolder "$($StageReleasePath)\docs\" -Force -WithModulePage -Locale 'en-US' -FwLink $FwLink -HelpVersion $Script:Version

    # Replace each missing element we need for a proper generic module page .md file
    $ModulePageFileContent = Get-Content -raw $ModulePage
    $ModulePageFileContent = $ModulePageFileContent -replace '{{Manually Enter Description Here}}', $Script:Manifest.Description
    $Script:FunctionsToExport | Foreach-Object {
        Write-Host "      Updating definition for the following function: $($_)"
        $TextToReplace = "{{Manually Enter $($_) Description Here}}"
        $ReplacementText = (Get-Help -Detailed $_).Synopsis
        $ModulePageFileContent = $ModulePageFileContent -replace $TextToReplace, $ReplacementText
    }
    $ModulePageFileContent | Out-File $ModulePage -Force -Encoding:utf8

    $MissingDocumentation = Select-String -Path "$($StageReleasePath)\docs\*.md" -Pattern "({{.*}})"
    if ($MissingDocumentation.Count -gt 0) {
        Write-Host -ForegroundColor Yellow ''
        Write-Host -ForegroundColor Yellow '   The documentation that got generated resulted in missing sections which should be filled out.'
        Write-Host -ForegroundColor Yellow '   Please review the following sections in your comment based help, fill out missing information and rerun this build:'
        Write-Host -ForegroundColor Yellow '   (Note: This can happen if the .EXTERNALHELP CBH is defined for a function before running this build.)'
        Write-Host ''
        Write-Host -ForegroundColor Yellow "Path of files with issues: $($StageReleasePath)\docs\"
        Write-Host ''
        $MissingDocumentation | Select-Object FileName,Matches | Format-Table -auto
        Write-Host -ForegroundColor Yellow ''
        pause

        throw 'Missing documentation. Please review and rebuild.'
    }

    Write-Host -NoNewLine '      Creating markdown documentation with PlatyPS'
    Write-Host -ForegroundColor Green '...Complete!'
}

# Synopsis: Build the markdown help files with PlatyPS
task CreateExternalHelp {
    Write-Host -NoNewLine '      Creating markdown help files'
    $null = New-ExternalHelp "$($StageReleasePath)\docs" -OutputPath "$($StageReleasePath)\en-US\" -Force
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Build the help file CAB with PlatyPS
task CreateUpdateableHelpCAB {
    Write-Host -NoNewLine "      Creating updateable help cab file"
    $LandingPage = "$($StageReleasePath)\docs\$($ProjectName).md"
    $null = New-ExternalHelpCab -CabFilesFolder "$($StageReleasePath)\en-US\" -LandingPagePath $LandingPage -OutputFolder "$($StageReleasePath)\en-US\"
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Create a new version release directory for our release and copy our contents to it
task PushVersionRelease {
    $ThisReleasePath = Join-Path $ReleasePath $Script:Version
    $null = Remove-Item $ThisReleasePath -Force -Recurse -ErrorAction 0
    $null = New-Item $ThisReleasePath -ItemType:Directory
    Copy-Item -Path "$($StageReleasePath)\*" -Destination $ThisReleasePath -Recurse
    Out-Zip $StageReleasePath $ReleasePath\$ProjectName'-'$Version'.zip' -overwrite
    Write-Host -NoNewLine "      Pushing a version release to $($ThisReleasePath)"
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Create the current release directory and copy this build to it.
task PushCurrentRelease {
    $null = Remove-Item $CurrentReleasePath -Force -Recurse -ErrorAction 0
    $null = New-Item $CurrentReleasePath -ItemType:Directory
    Copy-Item -Path "$($StageReleasePath)\*" -Destination $CurrentReleasePath -Recurse
    Out-Zip $StageReleasePath $ReleasePath\$ProjectName'-current.zip' -overwrite
    Write-Host -NoNewLine "      Pushing a version release to $($CurrentReleasePath)"
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Push with a version tag.
task GitPushRelease Version, {
	$changes = exec { git status --short }
	assert (-not $changes) "Please, commit changes."

	exec { git push }
	exec { git tag -a "v$($Script:Version)" -m "v$($Script:Version)" }
	exec { git push origin "v$($Script:Version)" }
}

# Synopsis: Push to github
task GithubPush Version, {
    exec { git add . }
    if ($ReleaseNotes -ne $null) {
        exec { git commit -m "$ReleaseNotes"}
    }
    else {
        exec { git commit -m "$($Script:Version)"}
    }
    exec { git push origin master }
	$changes = exec { git status --short }
	assert (-not $changes) "Please, commit changes."
}

# Synopsis: Create a new .psgallery project profile file (.psgallery)
task NewPSGalleryProfile Configure, {
    $PSGallaryParams = @{}
    $PSGallaryParams.Path = "$($CurrentReleasePath)"
    $PSGallaryParams.ProjectUri = $ModuleWebsite
    If ($ReleaseNotes -ne $null) {
        $PSGallaryParams.ReleaseNotes = $ReleaseNotes
    }

    # Update our gallary data with any tags from the manifest file (if they exist)
    if ( $Script:Manifest.PrivateData.PSdata.Keys -contains 'Tags') {
        $PSGallaryParams.Tags  = ($Script:Manifest.PrivateData.PSData.Tags | ForEach-Object {$_}) -join ','
    }
    if ( $Script:Manifest.PrivateData.PSdata.Keys -contains 'LicenseUri') {
        if ($Script:Manifest.PrivateData.PSData.LicenseUri -ne $null) {
            $PSGallaryParams.LicenseUri = $Script:Manifest.PrivateData.PSData.LicenseUri
        }
    }
    if ( $Script:Manifest.PrivateData.PSdata.Keys -contains 'IconUri') {
        if ($Script:Manifest.PrivateData.PSData.IconUri -ne $null) {
            $PSGallaryParams.IconUri = $Script:Manifest.PrivateData.PSData.IconUri
        }
    }

    New-PSGalleryProjectProfile @PSGallaryParams
    Write-Host -NoNewLine "      Updating .psgallery profile"
    Write-Host -ForeGroundColor green '...Complete!'

}

# Synopsis: Update the psgallery project profile data file
task UpdatePSGalleryProfile Configure, {
    $PSGallaryParams = @{}
    $PSGallaryParams.Path = "$($CurrentReleasePath)"
    $PSGallaryParams.ProjectUri = $ModuleWebsite
    If ($ReleaseNotes -ne $null) {
        $PSGallaryParams.ReleaseNotes = $ReleaseNotes
    }

    # Update our gallary data with any tags from the manifest file (if they exist)
    if ( $Script:Manifest.PrivateData.PSdata.Keys -contains 'Tags') {
        $PSGallaryParams.Tags  = ($Script:Manifest.PrivateData.PSData.Tags | ForEach-Object {$_}) -join ','
    }
    if ( $Script:Manifest.PrivateData.PSdata.Keys -contains 'LicenseUri') {
        if ($Script:Manifest.PrivateData.PSData.LicenseUri -ne $null) {
            $PSGallaryParams.LicenseUri = $Script:Manifest.PrivateData.PSData.LicenseUri
        }
    }
    if ( $Script:Manifest.PrivateData.PSdata.Keys -contains 'IconUri') {
        if ($Script:Manifest.PrivateData.PSData.IconUri -ne $null) {
            $PSGallaryParams.IconUri = $Script:Manifest.PrivateData.PSData.IconUri
        }
    }

    Update-PSGalleryProjectProfile @PSGallaryParams
    Write-Host -NoNewLine "      Updating .psgallery profile"
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Push the project to PSScriptGallery
task PublishPSGallery UpdatePSGalleryProfile, {
    Upload-ProjectToPSGallery
    Write-Host -NoNewLine "      Uploading project to PSGallery"
    Write-Host -ForeGroundColor green '...Complete!'
}

# Synopsis: Remove session artifacts like loaded modules and variables
task BuildSessionCleanup {
    # Clean up loaded modules if they are loaded
    $RequiredModules | ForEach-Object {
        Write-Output "      Removing $($_) module (if loaded)."
        Remove-Module $_  -Erroraction Ignore
    }
    Write-Output "      Removing $ProjectName module  (if loaded)."
    Remove-Module $ProjectName -Erroraction Ignore
}

# Synopsis: The default build
task . `
        Configure,
	    Clean,
        PrepareStage,
        FormatCode,
        CreateHelp,
        CreateModulePSM1,
        PushVersionRelease,
        PushCurrentRelease,
        BuildSessionCleanup

# Synopsis: Build without code formatting
task BuildWithoutCodeFormatting `
        Configure,
	    Clean,
        PrepareStage,
        CreateHelp,
        CreateModulePSM1,
        PushVersionRelease,
        PushCurrentRelease,
        BuildSessionCleanup

# Synopsis: Build module without combining source files
task BuildWithoutCombiningSource `
        Configure,
	    Clean,
        PrepareStage,
        FormatCode,
        CreateHelp,
        CopyModulePSM1,
        PushVersionRelease,
        PushCurrentRelease,
        BuildSessionCleanup

# Synopsis: Test the code formatting module only
task TestCodeFormatting Configure, Clean, PrepareStage, FormatCode
