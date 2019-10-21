# Psake makes variables declared here available in other scriptblocks
# Initialise additional variables
Properties {

    # Find the build folder based on build system
    $ProjectRoot = $ENV:BHProjectPath
    if (-not $ProjectRoot) { $ProjectRoot = $PSScriptRoot }

    # UNIX formatted time and date stamp
    $TimeStamp = Get-Date -UFormat "%Y%m%d-%H%M%S"

    # PowerShell major version
    $PSVerMaj = $PSVersionTable.PSVersion.Major

    # XML file name for test results
    $TestFileName = "TestResults_PS$PSVerMaj`_$TimeStamp.xml"

    # Text separator on output
    $Lines = '----------------------------------------------------------------------'

    # Verbose option for build
    $Verbose = @{ }
    if ($ENV:BHCommitMessage -match "!verbose") { $Verbose = @{ Verbose = $True } }
}

Task Default -Depends Deploy
Write-Output -InputObject "`n"

# Build system details displayed
Task Init {

    Write-Output -InputObject $Lines
    Set-Location -Path $ProjectRoot
    Write-Output -InputObject "`nBuild system details:"
    Get-Item -Path ENV:BH*
    Write-Output -InputObject "`n"
}

# Module check with a PowerShell script analyser
Task Check -Depends Init {

    Write-Output -InputObject $Lines
    Write-Output -InputObject "`nStatus: Checking files with 'PSScriptAnalyzer'"
    $Analysis = Invoke-ScriptAnalyzer -Path $ProjectRoot | Format-Table -AutoSize
    $Analysis
    if (($Analysis.Severity -contains "Error") -or ($Analysis.Severity -contains "ParseError")) {

        Write-Error -Message "Build failed due to errors found during analysis."
    }
}

# Module testing
Task Test -Depends Check {

    Write-Output -InputObject $Lines
    Write-Output -InputObject "`nStatus: Testing with PowerShell $PSVerMaj`n"

    # Test result collection within variable and file
    $TestFilePath = "$ProjectRoot\$TestFileName"
    $TestRslts = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile $TestFilePath

    # File upload when build system is 'AppVeyor'
    if ($ENV:BHBuildSystem -eq 'AppVeyor') {

        (New-Object -TypeName 'System.Net.WebClient').UploadFile(

            "https://ci.appveyor.com/api/testresults/nunit/$($ENV:APPVEYOR_JOB_ID)",
            $TestFilePath
        )
    }

    Remove-Item -Path $TestFilePath -Force -ErrorAction SilentlyContinue

    # Failed test stop
    if ($TestRslts.FailedCount -gt 0) {

        Write-Error -Message "Build failed due to '$($TestRslts.FailedCount)' failed tests."
    }
    Write-Output -InputObject "`n"
}

# Module loaded, read the exported functions, update the '.psd1' manifest file 'FunctionsToExport' value
Task Build -Depends Test {

    Write-Output -InputObject $Lines

    Set-ModuleFunction -Name "$ENV:BHPSModulePath\$ENV:BHProjectName.psm1"

    # Module version bumped
    try {

        $Ver = Get-NextNugetPackageVersion -Name $ENV:BHProjectName -ErrorAction Stop
        Update-Metadata -Path $ENV:BHPSModuleManifest -PropertyName ModuleVersion -Value $Ver -ErrorAction Stop
    }
    catch {

        "Failed to update version for '$ENV:BHProjectName': $PSItem.`nContinuing with existing version" |
        Write-Output
    }
    Write-Output -InputObject "`n"
}

# Module deployment
Task Deploy -Depends Build {

    Write-Output -InputObject "$Lines`n"

    Invoke-PSDeploy -Path $ProjectRoot -Force @Verbose
}