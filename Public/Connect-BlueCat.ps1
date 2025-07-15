function Connect-BlueCat {
<#
.SYNOPSIS
    Connect to a BlueCat IPAM appliance using the API in order to use commands from the BlueCatPoSh module.
.DESCRIPTION
    The Connect-BlueCat cmdlets connects an API authorized account to the BlueCat IPAM API. Your account must
    be authorized to use the API to connect with the BlueCatPoSh module. Multiple simultaneous connections are
    supported with a default connection being saved to the script level variable $BlueCatSession. Each active
    connection can optionally be configured with a default configuration (Set-BlueCatConfiguration) and default
    view (Set-BlueCatView) which will be used if a specific configuration/view are not specified for cmdlets.
.PARAMETER Server
    A string variable that specifies the name or IP address of the BlueCat IPAM appliance.
.PARAMETER Credential
    A PSCredential variable that contains the username and password of an API authorized user.
    This variable can be piped to the cmdlet.
.PARAMETER PassThru
    A switch that if specified causes a BlueCat object to be returned to the calling user/script.
    Using the PassThru switch will block the update of the default BlueCat session.
.EXAMPLE
    PS> Connect-BlueCat -Server mybluecat.company.com -Credential $MyBlueCatCredential

    Creates a new BlueCat session using the supplied Credential variable.
    The new session will be added to the list of all active sessions.
    The default session will be updated to point to this session.
    No output will be returned to the calling user/script.
.EXAMPLE
    PS> $MyBlueCatSession = Get-Credential | Connect-BlueCat -Server mybluecat.company.com -PassThru

    Calls the Get-Credential cmdlet and pipes the output into Connect-BlueCat.
    The new session will be added to the list of all active sessions.
    PassThru: The default session will NOT be updated.
    PassThru: A new [BlueCat] object will be returned to the calling user/script.
.INPUTS
    [System.Management.Automation.PSCredential] can be piped to Connect-BlueCat as the API login credential.
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a [BlueCat] object will be returned.
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(ValueFromPipeline,Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Credential -eq [System.Management.Automation.PSCredential]::Empty) {
            $Credential = Get-Credential -UserName $env:USERNAME -Message "Credentials for BlueCat Appliance ($($Server))"
        }

        try {
            $NewSession = [BlueCat]::new($Server, $Credential)
            Write-Verbose "$($thisFN): Logged in as $($NewSession.Username)@$($NewSession.Server) [$($NewSession.SessionStart)]"
        } catch {
            Write-Verbose "$($thisFN): Login as $($Credential.UserName)@$($Server) failed: $($_)"
            throw $_
        }

        # Update the internal list of all active BlueCat sessions
        $Script:BlueCatAllSessions += $NewSession
        if ($PassThru) {
            # Return the new session instance, but do not update the default session
            $NewSession
        } else {
            # Update the default session and return nothing
            $Script:BlueCatSession = $NewSession
        }
    }
}
