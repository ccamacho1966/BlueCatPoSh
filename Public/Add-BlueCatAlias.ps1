function Add-BlueCatAlias
{
<#
.SYNOPSIS
    Create a new DNS Alias (CNAME) record.
.DESCRIPTION
    The Add-BlueCatAlias cmdlet will create a new DNS CNAME record.

    A Canonical Name (CNAME) record is a type of resource record in the Domain Name System (DNS) that maps one domain name (an alias) to another (the canonical name).
    
    CNAME records must always point to another domain name, never directly to an IP address.

    If a CNAME record is present at a node, no other data should be present; this ensures that the data for a canonical name and its aliases cannot be different.
.PARAMETER Name
    A string value representing the FQDN of the CNAME (Alias) to be created.
.PARAMETER LinkedHost
    A string value representing the FQDN of the actual host the CNAME points to.
    The target must already exist as an internal or external host record.
.PARAMETER TTL
    An integer value representing time-to-live for the new CNAME record.
    A value of -1 will set the new record to use the zone default TTL.

    If not specified, BlueCatPoSh will default this value to -1 (use zone default).
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new CNAME record to be returned.
.EXAMPLE
    PS> Add-BlueCatAlias -Name myalias.example.com -LinkedHost realserver.example.com

    Create a new CNAME record for the alias 'myalias' in the example.com zone.
    Linked host (canonical name) is realserver.example.com.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
    TTL will default to the zone default time-to-live.
.EXAMPLE
    PS> Add-BlueCatAlias -Name myservice.example.com -LinkedHost somehost.someplace.com -TTL 300 -ViewID 23456 -BlueCatSession $Session6 -PassThru

    Create a new CNAME record for the alias 'myservice' in the example.com zone in view 23456.
    Linked host (canonical name) is somehost.someplace.com.
    TTL for this record will be set to 300 seconds (5 minutes).
    Use the BlueCatSession associated with $Session6 to create this record.

    A PSCustomObject representing the new CNAME record will be returned (PassThru).
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new CNAME record will be returned.
.LINK
    https://www.rfc-editor.org/rfc/rfc1034
    https://www.rfc-editor.org/rfc/rfc2181
    https://en.wikipedia.org/wiki/CNAME_record
#>
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
