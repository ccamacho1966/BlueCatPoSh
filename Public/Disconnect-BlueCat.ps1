function Disconnect-BlueCat {
<#
.SYNOPSIS
    Disconnect an active BlueCatPoSh session.
.DESCRIPTION
    The Disconnect-BlueCat cmdlet ends an active BlueCatPoSh session. This invokes the logout API endpoint
    to cleanly terminate the session to the IPAM appliance. The session is removed from the list of active
    sessions. If you disconnect the module default session the $BlueCatSession variable will be set to $null.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be disconnected.
.EXAMPLE
    PS> Disconnect-BlueCat

    Disconnects the current default active BlueCat session listed in the $BlueCatSession variable.
    The session will be removed from the list of all active sessions.
    The default session will be set to $null.
    .EXAMPLE
    PS> Disconnect-BlueCat -BlueCatSession $MyBlueCatSession

    Disconnects the active BlueCat session listed in $MyBlueCatSession.
    The session will be removed from the list of all active sessions.
    If this is the default session then $BlueCatSession will be set to $null.
.EXAMPLE
    PS> $MyBlueCatSession | Disconnect-BlueCat

    Disconnects the active BlueCat session piped into the cmdlet.
    The session will be removed from the list of all active sessions.
    If this is the default session then $BlueCatSession will be set to $null.
.INPUTS
    [BlueCat] can be piped to the Disconnect-BlueCat cmdlet.
.OUTPUTS
    None.
#>
    [CmdletBinding()]

    param(
        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if (-not $BlueCatSession) {
            # If we're using the default then erase the default
            $BlueCatSession = $Script:BlueCatSession
        }

        if ($BlueCatSession) {
            if ($BlueCatSession.idTag -eq $Script:BlueCatSession.idTag) {
                # If this is the default session then set the module reference to $null
                Write-Verbose "$($thisFN): Default BlueCatSession has been reset to NULL"
                $Script:BlueCatSession = $null
            }

            # Remove this session from the internal list of active BlueCat sessions
            [BlueCat[]] $Script:BlueCatAllSessions = $Script:BlueCatAllSessions | Where-Object -Property 'idTag' -NE -Value $BlueCatSession.idTag

            # Invoke the API logout endpoint, but do not trigger an error if it fails
            $Result = Invoke-BlueCatApi -Method Get -Request 'logout' -BlueCatSession $BlueCatSession -ErrorAction SilentlyContinue
            Write-Verbose "$($thisFN): $($Result)"
        } else {
            Write-Verbose "$($thisFN): No active BlueCat session to disconnect"
        }
    }
}
