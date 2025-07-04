Function Add-BlueCatMX {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string] $FQDN,

        [parameter(Mandatory)]
        [int] $Priority,

        [parameter(Mandatory)]
        [string] $Relay,

        [int] $TTL = -1,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $MXInfo = Resolve-BlueCatFQDN -BlueCatSession $BlueCatSession -FQDN $FQDN

        if (-not $MXInfo.zone) {
            # No deployable zone was found for MX record
            Throw "No deployable zone was found for $($FQDN)"
        }
        Write-Verbose "BlueCat: Add-MX: Selected Zone #$($MXInfo.zone.id) as '$($MXInfo.zone.name)'"

        if ($MXInfo.external) {
            Write-Warning "BlueCat: Add-MX: An external host entry exists for '$($MXInfo.external.name)'"
        }

        if ($MXInfo.alias) {
            Throw "Aborting MX record creation: Alias/CName record for $($FQDN) found!"
        }

        $relayInfo = Resolve-BlueCatFQDN -BlueCatSession $BlueCatSession -FQDN $Relay
        if ($relayInfo.external) {
            $relayName = $relayInfo.external.name
        } elseif ($relayInfo.host) {
            $relayName = $relayInfo.host.name
        } else {
            throw "Aborting MX record creation: No host record found for relay $($Relay)"
        }

        if ($MXInfo.shortName) { $MXName = $MXInfo.name }
        else { $MXName = '.'+$MXInfo.name }

        $Uri = "addMXRecord?viewId=$($MXInfo.view.id)&absoluteName=$($MXName)&priority=$($Priority)&linkedRecordName=$($relayName)&ttl=$($TTL)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Uri
        if (-not $result) { throw "MX creation failed for $($FQDN) - $($result)" }

        Write-Verbose "BlueCat: Add-MX: Created MX #$($result) for '$($MXInfo.name)' (points to $($relayName) priority $($Priority))"

        if ($PassThru) { Get-BlueCatMX -Name $MXInfo.name -BlueCatSession $BlueCatSession }
    }
}
