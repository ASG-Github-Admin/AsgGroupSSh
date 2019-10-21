function Get-CallerPreference {

    <#
    .SYNOPSIS
    Fetches "Preference" variable values from the caller's scope.
    
    .DESCRIPTION
    Script module functions do not automatically inherit their caller's variables, but they can be obtained
    through the $PSCmdlet variable in Advanced Functions.  This function is a helper function for any script
    module Advanced Function; by passing in the values of $ExecutionContext.SessionState and $PSCmdlet, 
    Get-CallerPreference will set the caller's preference variables locally.

    .PARAMETER Cmdlet
    The $PSCmdlet object from a script module Advanced Function.

    .PARAMETER SessionState
    The $ExecutionContext.SessionState object from a script module Advanced Function. This is how the
    Get-CallerPreference function sets variables in its callers' scope, even if that caller is in a different
    script module.

    .PARAMETER Name
    Optional array of parameter names to retrieve from the caller's scope. Default is to retrieve all preference
    variables as defined in the about_Preference_Variables help file (as of PowerShell 4.0). This parameter may
    also specify names of variables that are not in the about_Preference_Variables help file, and the function
    will retrieve and set those as well.
    
    .EXAMPLE
    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Imports the default PowerShell preference variables from the caller into the local scope.

    .EXAMPLE
    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'ErrorActionPreference', 'SomeOtherVariable'

    Imports only the ErrorActionPreference and SomeOtherVariable variables into the local scope.

    .EXAMPLE
    'ErrorActionPreference','SomeOtherVariable' | Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Same as Example 2, but sends variable names to the Name parameter via pipeline input.
    
    .INPUTS
    System.String

    .OUTPUTS
    None.
    
    This function does not produce pipeline output.

    .LINK
    about_Preference_Variables
    #>

    #Requires -Version 2

    [CmdletBinding(DefaultParameterSetName = 'AllVariables')]
    param (

        [Parameter(Mandatory)]
        [ValidateScript( { $PSItem.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' })]
        $Cmdlet,

        [Parameter(Mandatory)][System.Management.Automation.SessionState]$SessionState,

        [Parameter(ParameterSetName = 'Filtered', ValueFromPipeline)][string[]]$Name
    )

    begin {

        $FilterHash = @{ }
    }
    
    process {

        if ($null -ne $Name) {

            foreach ($String in $Name) {

                $FilterHash[$String] = $true
            }
        }
    }

    end {

        # List of preference variables taken from the about_Preference_Variables help file in PowerShell version 4.0
        $Vars = @{

            'ErrorView'                     = $null
            'FormatEnumerationLimit'        = $null
            'LogCommandHealthEvent'         = $null
            'LogCommandLifecycleEvent'      = $null
            'LogEngineHealthEvent'          = $null
            'LogEngineLifecycleEvent'       = $null
            'LogProviderHealthEvent'        = $null
            'LogProviderLifecycleEvent'     = $null
            'MaximumAliasCount'             = $null
            'MaximumDriveCount'             = $null
            'MaximumErrorCount'             = $null
            'MaximumFunctionCount'          = $null
            'MaximumHistoryCount'           = $null
            'MaximumVariableCount'          = $null
            'OFS'                           = $null
            'OutputEncoding'                = $null
            'ProgressPreference'            = $null
            'PSDefaultParameterValues'      = $null
            'PSEmailServer'                 = $null
            'PSModuleAutoLoadingPreference' = $null
            'PSSessionApplicationName'      = $null
            'PSSessionConfigurationName'    = $null
            'PSSessionOption'               = $null

            'ErrorActionPreference'         = 'ErrorAction'
            'DebugPreference'               = 'Debug'
            'ConfirmPreference'             = 'Confirm'
            'WhatIfPreference'              = 'WhatIf'
            'VerbosePreference'             = 'Verbose'
            'WarningPreference'             = 'WarningAction'
        }


        foreach ($Entry in $Vars.GetEnumerator()) {

            if (([string]::IsNullOrEmpty($Entry.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($Entry.Value)) -and
                ($PSCmdlet.ParameterSetName -eq 'AllVariables' -or $FilterHash.ContainsKey($Entry.Name))) {
                $Variable = $Cmdlet.SessionState.PSVariable.Get($Entry.Key)
                
                if ($null -ne $Variable) {

                    if ($SessionState -eq $ExecutionContext.SessionState) {

                        Set-Variable -Scope 1 -Name $Variable.Name -Value $Variable.Value -Force -Confirm:$false -WhatIf:$false
                    }
                    else {

                        $SessionState.PSVariable.Set($Variable.Name, $Variable.Value)
                    }
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'Filtered') {

            foreach ($VarName in $FilterHash.Keys) {

                if (-not $Vars.ContainsKey($VarName)) {

                    $Variable = $Cmdlet.SessionState.PSVariable.Get($VarName)
                
                    if ($null -ne $Variable) {

                        if ($SessionState -eq $ExecutionContext.SessionState) {

                            Set-Variable -Scope 1 -Name $Variable.Name -Value $Variable.Value -Force -Confirm:$false -WhatIf:$false
                        }
                        else {

                            $SessionState.PSVariable.Set($Variable.Name, $Variable.Value)
                        }
                    }
                }
            }
        }
    }
}