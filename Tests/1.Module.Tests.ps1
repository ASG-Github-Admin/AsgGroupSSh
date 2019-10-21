$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$ModuleRoot = Split-Path (Resolve-Path "$ProjectRoot\*\*.psm1")
$ModuleName = Split-Path $ModuleRoot -Leaf

Describe "General project validation: '$ModuleName'" {

    $Scripts = Get-ChildItem -Path $ProjectRoot -Include *.ps1, *.psm1, *.psd1 -Recurse

    # TestCases are splatted to the script so we need hashtables
    $TestCase = $Scripts | Foreach-Object -Process { @{ File = $PSItem } }
      
    It "Script <File> should be a valid PowerShell format" -TestCases $TestCase {

        param ($File)

        $File.FullName | Should Exist

        $Contents = Get-Content -Path $File.FullName -ErrorAction Stop
        $Errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($Contents, [ref] $Errors)
        $Errors.Count | Should Be 0
    }

    It "Module '$ModuleName' should import cleanly" {
        
        { Import-Module (Join-Path -Path $ModuleRoot -ChildPath "$ModuleName.psm1") -Force } | Should Not Throw
    }
}

