param ($Task = 'Default')

# Grab nuget bits, install modules, set build variables, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

Install-Module -Name Psake, PSDeploy, BuildHelpers, PSScriptAnalyzer -Force
Install-Module -Name Pester -Force -SkipPublisherCheck
Import-Module -Name Psake, BuildHelpers

Set-BuildEnvironment

Invoke-psake -buildFile .\psake.ps1 -taskList $Task -nologo
exit ([int] (-not $psake.build_success))