function Add-BlueCatTXT {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(Mandatory)]
        [string] $FQDN,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

        [int]$TTL = -1,

        [switch]$PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $TextInfo = Resolve-BlueCatFQDN -BlueCatSession $BlueCatSession -FQDN $FQDN

        if ($TextInfo.zone) {
            Write-Verbose "Add-BlueCatTXT: Selected Zone #$($TextInfo.zone.id) as '$($TextInfo.zone.name)'"
        } else {
            # No deployable zone was found for TXT record
            throw "No deployable zone was found for $($FQDN)"
        }

        if ($TextInfo.external) {
            Write-Warning "Add-BlueCatTXT: An external host entry exists for '$($TextInfo.external.name)'"
        }

        if ($TextInfo.alias) {
            throw "Aborting TXT record creation: Alias/CName record for $($FQDN) found!"
        }

        if ($TextInfo.shortName) {
            $TextName = $TextInfo.name
        } else {
            $TextName = '.'+$TextInfo.name
        }

        $TextString = [uri]::EscapeDataString($Text.Trim('"'))
        $Uri = "addTXTRecord?viewId=$($TextInfo.view.id)&absoluteName=$($TextName)&txt=$($TextString)&ttl=$($TTL)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Uri
        if (-not $result) {
            throw "TXT creation failed for $($Host) - $($result)"
        }

        Write-Verbose "Add-BlueCatTXT: Created #$($result) for '$($TextInfo.name)'"

        if ($PassThru) { Get-BlueCatTXT -BlueCatSession $BlueCatSession -HostName $TextInfo.name }
    }
}
