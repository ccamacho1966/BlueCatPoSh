function Add-BlueCatAlias {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Alias')]
        [string] $Name,

        [parameter(Mandatory)]
        [Alias('Value')]
        [string] $LinkedHost,

        [int] $TTL, # used to default to -1

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $AliasInfo = Resolve-BlueCatFQDN -BlueCatSession $BlueCatSession -FQDN $Name
        if (-not $AliasInfo.zone) {
            # No deployable zone was found for Alias/CName
            throw "No deployable zone was found for $($Name)"
        }
        Write-Verbose "Add-BlueCatAlias: Selected Zone #$($AliasInfo.zone.id) as '$($AliasInfo.zone.name)'"

        if ($AliasInfo.host) {
            # There is already a host entry for this Alias/CName!!
            throw "Existing host record found - aborting Alias creation!"
        }

        if ($AliasInfo.external) {
            Write-Warning "Add-BlueCatAlias: An external host entry exists for '$($AliasInfo.external.name)'"
        }

        $LinkedInfo = Resolve-BlueCatFQDN -Connection $BlueCatSession -FQDN $LinkedHost
        $propString = "absoluteName=$($AliasInfo.name)|linkedRecordName=$($LinkedInfo.name)|"
        if ($TTL) {
            $propString += "ttl=$($TTL)|"
        }
        if ($LinkedInfo.host) {
            $propString += "linkedParentZoneName=$($LinkedInfo.zone.name)|"
        } elseif (-not $LinkedInfo.external) {
            # Nothing to link to...
            throw "$(LinkedHost) is not in the database. A host or external host entry must be created first!"
        }

        $aliasObj = New-Object -TypeName psobject
        $aliasObj | Add-Member -MemberType NoteProperty -Name name       -Value $AliasInfo.shortName
        $aliasObj | Add-Member -MemberType NoteProperty -Name type       -Value 'AliasRecord'
        $aliasObj | Add-Member -MemberType NoteProperty -Name properties -Value $propString

        $Body = $aliasObj | ConvertTo-Json
        $Query = "addEntity?parentId=$($AliasInfo.zone.id)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Query -Body $Body
        if (-not $result.id) { throw "Alias creation failed for $($Name) - $($result)" }

        Write-Verbose "Add-BlueCatAlias: Created #$($result) as '$($AliasInfo.name)' (points to '$($LinkedInfo.name)')"

        if ($PassThru) { Get-BlueCatAlias -BlueCatSession $BlueCatSession -Name $Name }
    }
}
