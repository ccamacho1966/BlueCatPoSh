function Add-BlueCatAlias {
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [Alias('Alias')]
        [string] $Name,

        [parameter(Mandatory)]
        [Alias('Value')]
        [string] $LinkedHost,

        [int] $TTL = -1,

        [Parameter(ParameterSetName='ViewID')]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $Name = $Name.TrimEnd('\.')
        $LookupParms = @{
            FQDN           = $Name
            BlueCatSession = $BlueCatSession
        }
        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        }

        $AliasInfo = Resolve-BlueCatFQDN @LookupParms
        if (-not $AliasInfo.zone) {
            # No deployable zone was found for Alias/CName
            throw "No deployable zone was found for $($Name)"
        }
        Write-Verbose "$($thisFN): Selected Zone #$($AliasInfo.zone.id) as '$($AliasInfo.zone.name)'"

        if ($AliasInfo.alias) {
            # There is already an existing alias
            throw "Existing alias record found - aborting Alias creation!"
        }

        if ($AliasInfo.host) {
            # There is already a host entry for this Alias/CName!!
            throw "Existing host record found - aborting Alias creation!"
        }

        if ($AliasInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($AliasInfo.external.name)'"
        }

        $LookupParms.FQDN = $LinkedHost
        $LinkedInfo = Resolve-BlueCatFQDN @LookupParms
        $propString = "absoluteName=$($AliasInfo.name)|linkedRecordName=$($LinkedInfo.name)|ttl=$($TTL)|"
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
        $result = Invoke-BlueCatApi -Method Post -Request $Query -Body $Body -BlueCatSession $BlueCatSession
        if (-not $result.id) {
            throw "Alias creation failed for $($Name) - $($result)"
        }

        Write-Verbose "$($thisFN): Created #$($result) as '$($AliasInfo.name)' (points to '$($LinkedInfo.name)')"

        if ($PassThru) {
            $LookupParms.FQDN = $Name
            Get-BlueCatAlias @LookupParms
        }
    }
}
