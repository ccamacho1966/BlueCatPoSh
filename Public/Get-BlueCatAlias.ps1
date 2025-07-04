function Get-BlueCatAlias { # also known as CNAME
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(Mandatory)]
        [Alias('CNAME','Alias')]
        [string] $Name
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $BlueCatSession | Confirm-Settings -Config -View

        $ZIobj = Convert-FQDNtoDeployZone -BlueCatSession $BlueCatSession -FQDN $Name
        if (!$ZIobj.zone) { throw "No deployable zone found for $($Name.TrimEnd('\.'))!" }

        $Query = "getEntityByName?parentId=$($ZIobj.zone.id)&type=AliasRecord&name=$($ZIobj.shortName)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

        if (!$result.id) { throw "No Alias/CName record found for $($Name.TrimEnd('\.'))" }

        $AliasObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        $AliasObj | Add-Member -MemberType NoteProperty -Name zone -Value $ZIobj.zone

        Write-Verbose "Get-BlueCatAlias: Selected #$($AliasObj.id) as '$($AliasObj.name)' (points to '$($AliasObj.property.linkedRecordName)')"
        $AliasObj
    }
}
