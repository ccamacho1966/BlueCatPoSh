function Add-BlueCatExternalHost {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [Alias('ExternalHost')]
        [string] $Name,

        [Parameter()]
        [Alias('View')]
        [int] $ViewID,

        [psobject] $Properties,

        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
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

        $result = Get-BlueCatExternalHost -Name $xHost -ViewID $ViewID -BlueCatSession $BlueCatSession
        if ($result) { throw "Add-BlueCatExternalHost: $($xHost) already exists as Object #$($result.id)!" }

        $Uri = "addExternalHostRecord?viewId=$($ViewID)&name=$($xHost)"
        $result = Invoke-BlueCatApi -Connection $BlueCatSession -Method Post -Request $Uri
        if (!$result) { throw "Add-BlueCatExternalHost: Failed to create $($xHost): $($result)" }

        Write-Verbose "Add-BlueCatExternalHost: Created #$($result) as '$($xHost)'"

        if ($PassThru) { Get-BlueCatExternalHost -Name $xHost -ViewID $ViewID -BlueCatSession $BlueCatSession }
    }
}
