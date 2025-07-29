function Set-BlueCatConnection {
<#
.SYNOPSIS
    Sets the default BlueCat connection
.DESCRIPTION
    The Set-BlueCatConnection cmdlet accepts a BlueCat object as a parameter or on the pipeline. The default connection/session variable ($Script:BlueCatSession) will be updated to the supplied session.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to become the new default session.
.EXAMPLE
    PS> Set-BlueCatConnection -BlueCatSession $Session8

    Updates the default session to be $Session8
.EXAMPLE
    PS> $Session4 | Set-BlueCatConnection

    Updates the default session to be $Session4
.INPUTS
    [BlueCat] object can be piped to Set-BlueCatConnection
.OUTPUTS
    None.
#>
    [CmdletBinding()]

    param(
        [Parameter(ValueFromPipeline,Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $Script:BlueCatSession = $BlueCatSession
        Write-Verbose "$($thisFN): $($Script:BlueCatSession.Username)@$($Script:BlueCatSession.Server)"
    }
}
