function Get-BlueCatConnection {
<#
.SYNOPSIS
    Get information on active BlueCat connections
.DESCRIPTION
    The Get-BlueCatConnection cmdlet allows the retrieval of active BlueCat Connections.

    Calling the cmdlet with no parameters (or the -Default parameter) will return the current default connection, if any.

    Using the -All switch allows the retrieval of all active connections in the current PowerShell session.
.PARAMETER Default
    A switch that indicates the cmdlet should return the current default connection.

    This switch can be omitted as this is the default behavior.
.PARAMETER All
    A switch that indicates the cmdlet should return a list of all active connections.
.EXAMPLE
    PS> Get-BlueCatConnection

    Returns a PSCustomObject representing the current default BlueCat connection, or NULL if one is not set.
.EXAMPLE
    PS> Get-BlueCatConfig -All

    Returns a list of PSCustomObjects representing all configurations on the default BlueCat session. Returns NULL if there are no configurations configured.
.INPUTS
    None
.OUTPUTS
    One or more PSCustomObjects representing BlueCat connections.
#>
    [CmdletBinding(DefaultParameterSetName='Default')]

    param(
        [Parameter(ParameterSetName='Default')]
        [switch] $Default,

        [Parameter(ParameterSetName='All')]
        [switch] $All
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($All) {
            # Return a list of all currently active BlueCat sessions
            if ($Script:BlueCatAllSessions.Count) {
                if ($Script:BlueCatAllSessions.Count -eq 1) {
                    $s = ''
                } else {
                    $s = 's'
                }
                Write-Verbose "$($thisFN): $($Script:BlueCatAllSessions.Count) active session$($s)"

                $Script:BlueCatAllSessions
            } else {
                Write-Verbose "$($thisFN): NO ACTIVE SESSIONS"
            }
        } else {
            # Return only the current default BlueCat session
            if ($Script:BlueCatSession.Server) {
                Write-Verbose "$($thisFN): $($Script:BlueCatSession.Username)@$($Script:BlueCatSession.Server)"

                $Script:BlueCatSession
            } else {
                Write-Verbose "$($thisFN): NO DEFAULT SESSION"
            }
        }
    }
}
