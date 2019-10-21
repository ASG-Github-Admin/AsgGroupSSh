# Invoke-BAShSudoCommand
function Invoke-BAShSudoCommand {

    <#
    .SYNOPSIS
    Runs a Bourne Again Shell sudo command on a remote computer.

    .DESCRIPTION
    The Invoke-SudoCommand function runs sudo commands via secure shell on a remote computer and returns any
    output.

    .EXAMPLE
    PS C:\> Invoke-SudoCommand -Name LinuxServer -Port 22 -Command "sudo whoami" -Credential (Get-Credential)
    Description
    -----------
    This runs the command "whoami" with sudo on the computer 'LinuxServer' via secure shell on port 22.

    .PARAMETER Name
    Specifies the computer on which the sudo command runs. Use an IP address or a DNS name of the remote computer.

    .PARAMETER Port
    Specifies the network port on the remote computer that is used for a secure shell session. To connect to a 
    remote computer, it must be listening on the port that the connection uses. The default port is 22.

    .PARAMETER Command
    Specifies the command to run with sudo on the remote computer. Type in the command as you would do normally.

    .PARAMETER Credential
    Specifies a user account credential for the secure shell session connection, and has sudo permissions on the
    remote computer. Either pass a PSCredential object or respond to the prompt.

    .PARAMETER Timeout
    Specifies the timeout period for the sudo command to complete on the remote computer. The default is five
    seconds.

    .INPUTS
    System.String, System.Int16, System.Int32, pscredential

    .OUTPUTS
    System.String
    #>

    [CmdLetBinding()]
    param (

        # Remote computer name
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("ComputerName", "Computer", "Server")]
        [string] $Name,

        # Secure shell port number
        [ValidateNotNullOrEmpty()]
        [Alias("SSHPort")]
        [int32] $Port = 22,

        # Sudo command to invoke on the remote computer
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { 
        
                if ($PSItem -like "sudo*") { Write-Output -InputObject $true }
                else { throw "'$PSItem' does not start with the word 'sudo'." }
            }
        )]
        [Alias("SudoCommand", "SudoCmd", "Cmd")]
        [string] $Command,

        # Credential for secure shell authentication
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias("Cred")]
        [pscredential] $Credential,

        # Command Timeout
        [ValidateNotNullOrEmpty()]
        [Alias("Wait")]
        [int16] $Timeout = 5
    )

    begin {

        # Error handling
        Set-StrictMode -Version "Latest"
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        $CallerEA = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

        # Shorten the paramater variables
        $Cred = $Credential
        $Cmd = $Command
    }

    process {

        try {

            #TODO Create type names for xml output formatting in module

            # Create a secure shell session with computer
            Write-Debug -Message "Creating a secure shell session with '$Name' on '$Port'"
            Write-Verbose -Message "Creating a secure shell session"
            $Sesh = New-SSHSession -ComputerName $Name -Port $Port -Credential $Cred -AcceptKey
            if (-not $Sesh) { throw "A secure shell could not be created with '$Name' on '$Port'." }

            # Write debug information about the session
            $SeshCxnInfo = $Sesh.Session.ConnectionInfo
            Write-Debug -Message "Session information -"
            Write-Debug -Message "Identifier: $($Sesh.SessionId)"
            Write-Debug -Message "Host: $($Sesh.Host)"
            Write-Debug -Message "Port: $($SeshCxnInfo.Port)"
            Write-Debug -Message "Username: $($SeshCxnInfo.Username)"
            Write-Debug -Message "Encoding: $($SeshCxnInfo.Encoding)"
            Write-Debug -Message "Key exchange: $($SeshCxnInfo.CurrentKeyExchangeAlgorithm)"
            Write-Debug -Message "Server encryption: $($SeshCxnInfo.CurrentServerEncryption)"
            Write-Debug -Message "Client encryption: $($SeshCxnInfo.CurrentClientEncryption)"
            Write-Debug -Message "Server HMAC: $($SeshCxnInfo.CurrentServerHmacAlgorithm)"
            Write-Debug -Message "Client HMAC: $($SeshCxnInfo.CurrentClientHmacAlgorithm)"
            Write-Debug -Message "Host key: $($SeshCxnInfo.CurrentHostKeyAlgorithm)"
            Write-Debug -Message "Server compression: $($SeshCxnInfo.CurrentServerCompressionAlgorithm)"
            Write-Debug -Message "Client compression: $($SeshCxnInfo.CurrentClientCompressionAlgorithm)"
            Write-Debug -Message "Server version $($SeshCxnInfo.ServerVersion)"
            Write-Debug -Message "Client version: $($SeshCxnInfo.ClientVersion)"
            
            # Create a secure shell stream within the established session
            Write-Debug -Message "Creating a secure shell stream within the established session"
            Write-Verbose -Message "Creating a secure shell stream within the established session"
            $Stream = New-SSHShellStream -SSHSession $Sesh

            # Check that the user account has sudo permissions
            Write-Debug -Message "Checking that the user account '$($Cred.UserName)' has sudo permissions"
            Write-Verbose -Message "Checking that the user account has sudo permissions"
            $Params = @{

                ShellStream  = $Stream
                ExpectString = "[sudo] password for $($Cred.UserName):"
                SecureAction = $Cred.Password
            }
            $Invoke = Invoke-SSHStreamExpectSecureAction -Command "sudo whoami" @Params
            Start-Sleep -Seconds 1
            $Out = $Stream.Read()
            if (($Invoke -ne $true) -or ($Out -notmatch "^\s{2}\nroot\s\n\[$($Cred.UserName)@")) {

                throw "The user account '$($Cred.UserName)' does not have sudo permissions on '$Name'."
            }

            # Check that there is not a zero timeout set on sudo
            Write-Debug -Message "Checking that there is not a zero timeout set on sudo"
            Write-Verbose -Message "Checking that there is not a zero timeout set on sudo"
            $Invoke = Invoke-SSHStreamExpectSecureAction -Command "sudo whoami" -TimeOut 2 @Params
            Start-Sleep -Seconds 1
            $Out = $Stream.Read()
            if (($Invoke -eq $true) -or ($Out -notmatch "^sudo whoami\s\nroot\s\n\[$($Cred.UserName)@")) {

                throw "There is a zero timeout set on sudo on computer '$Name'."
            }

            # Invoke the command using the established stream
            Write-Debug -Message "Invoking the sudo command '$Cmd' within the established stream"
            Write-Verbose -Message "Invoking the sudo command within the established stream"
            do { $Stream.Read() | Out-Null } while ($Stream.DataAvailable) # Clear the stream in preparation
            $Stream.WriteLine($Cmd) # Send the command
            $Stream.ReadLine() | Out-Null # Clear the command from the stream
            Start-Sleep -Seconds 1 # Allow the command time to execute

            # Wait for the command to complete
            Write-Debug -Message "Waiting for the stream to return data - timeout is set to '$Timeout' second(s)"
            Write-Verbose -Message "Waiting for the command to complete"
            $Span = New-TimeSpan -Seconds $Timeout # Set the timeout for the command to complete
            $Out = $Stream.Expect([regex] "(\]\W $|\]\W\snohup: appending output to ``nohup.out'\s$)", $Span)

            # Timeout period reached
            if (-not $Out) { throw "The command '$Cmd' failed to complete within '$Timeout' seconds on '$Name'." }

            # Parse the data and output
            if ($Out.Length -eq 0) {
            
                Write-Debug -Message "No data to return"
                Write-Verbose -Message "No data to return"
                return
            }
            Write-Debug -Message "Parsing the data:`n$Out`n"
            Write-Verbose -Message "Parsing the data and outputting"
            Write-Output -InputObject $Out.SubString(0, $Out.LastIndexOf("[")).Trim()
        }
        catch { Write-Error -ErrorRecord $PSItem -EA $CallerEA }
        finally {
        
            # Remove the secure shell session           
            Write-Debug -Message "Removing the secure shell session"
            Write-Verbose -Message "Removing the secure shell session"
            Remove-SSHSession -SessionId 0 | Out-Null
        }
    }
    end { }
}