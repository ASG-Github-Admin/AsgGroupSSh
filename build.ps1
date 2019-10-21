param ($Task = 'Default')

# Grab nuget bits, install modules, set build variables, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

Install-Module -Name Psake, PSDeploy, BuildHelpers, PSScriptAnalyzer -Force
Install-Module -Name Pester -Force -SkipPublisherCheck
Install-Module -Name Posh-SSH -RequiredVersion "2.2" -Force
Import-Module -Name Psake, BuildHelpers

Set-BuildEnvironment

Invoke-psake -buildFile .\psake.ps1 -taskList $Task -nologo
exit ([int] (-not $psake.build_success))