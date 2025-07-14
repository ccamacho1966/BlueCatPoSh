function Add-BlueCatAlias
{
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('FQDN')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Target','Value')]
        [string] $LinkedHost,

        [Parameter()]
        [int] $TTL = -1,

        [Parameter(ParameterSetName='ViewID')]
        [int] $ViewID,

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

        $FQDN = $Name | Test-ValidFQDN
        $LookupParms = @{
            FQDN           = $FQDN
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
            throw "No deployable zone was found for $($FQDN)"
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

        $LookupLinked      = $LookupParms
        $NewLinked         = $LinkedHost | Test-ValidFQDN
        $LookupLinked.Name = $NewLinked

        $LinkedInfo        = Resolve-BlueCatFQDN @$LookupLinked
        $propString = "ttl=$($TTL)|absoluteName=$($AliasInfo.name)|linkedRecordName=$($LinkedInfo.name)|"
        if ($LinkedInfo.host) {
            $linkedName = $LinkedInfo.host.name
            Write-Verbose "$($thisFN): Found host record for linked host '$($linkedName)' (ID:$($LinkedInfo.host.id))"
            if ($LinkedInfo.external) {
                Write-Warning "$($thisFN): Both internal and external host entries found for $($linkedName)"
            }
            $propString += "linkedParentZoneName=$($LinkedInfo.zone.name)|"
        } elseif ($LinkedInfo.external) {
            $linkedName = $LinkedInfo.external.name
            Write-Verbose "$($thisFN): Found EXTERNAL host record for linked host '$($linkedName)' (ID:$($LinkedInfo.external.id))"
        } else {
            throw "Aborting CNAME record creation: No host record found for linked host $($NewLinked)"
        }

        $Body = @{
            type       = 'AliasRecord'
            name       = $AliasInfo.shortName
            properties = $propString
        }
        $CreateAliasRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($AliasInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateAliasRecord
        if (-not $BlueCatReply) {
            throw "CNAME record creation failed for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) as '$($AliasInfo.name)' (points to '$($linkedName)')"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
