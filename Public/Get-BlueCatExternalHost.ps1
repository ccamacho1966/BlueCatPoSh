function Get-BlueCatExternalHost {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('ExternalHost')]
        [string] $Name,

        [Parameter()]
        [Alias('View')]
        [int] $ViewID,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if (-not $ViewID) {
            # If no view is specified use the default view set for this connection
            # If the default view has not been set then an error will be thrown
            $BlueCatSession | Confirm-Settings -View
            $ViewID = $BlueCatSession.idView
        }

        $xHost = $Name.TrimEnd('\.')

        $Query = "getEntityByName?parentId=$($ViewID)&name=$($xHost)&type=ExternalHostRecord"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

        if (-not $result.id) {
            # Record not found. Return nothing/null.
            Write-Verbose "External Host Record for '$($xHost)' not found: $($result)"
        } else {
            # Found the external host - return the result
            Write-Verbose "Get-BlueCatExternalHost: Selected #$($result.id) as '$($result.name)'"

            # Build the full object and return
            $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
