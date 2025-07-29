function Add-BlueCatTXT
{
<#
.SYNOPSIS
    Create a new DNS TXT record.
.DESCRIPTION
    The Add-BlueCatText cmdlet will create a new DNS TXT record.

    A TXT record (short for text record) is a type of resource record in the Domain Name System (DNS) used to provide the ability to associate arbitrary text with a host or other name, such as human readable information about a server, network, data center, or other accounting information.[1]

    It is also often used in a more structured fashion to record small amounts of machine-readable data into the DNS. 
.PARAMETER Name
    A string value representing the FQDN to associate the new TXT record with.
.PARAMETER Text
    A string value containing the text for the new record.
.PARAMETER TTL
    An integer value representing time-to-live for the new TXT record.
    A value of -1 will set the new record to use the zone default TTL.

    If not specified, BlueCatPoSh will default this value to -1 (use zone default).
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new TXT record to be returned.
.EXAMPLE
    PS> Add-BlueCatText -Name _pki-validation.example.com -Text 'AJU9d7skja9sjKD0!x9'

    Create a new TXT record for the name '_pki-validation' in the example.com zone.
    The TXT value for this record is: AJU9d7skja9sjKD0!x9
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
    TTL will default to the zone default time-to-live.
.EXAMPLE
    PS> Add-BlueCatText -Name nyc._domainkey.example.com -Text 'k=rsa; t=s; p=ABC123' -TTL 300 -ViewID 23456 -BlueCatSession $Session9 -PassThru

    Create a new TXT record for the name 'nyc._domainkey' in the example.com zone in view 23456.
    The TXT value for this record is: k=rsa; t=s; p=ABC123
    TTL for this record will be set to 300 seconds (5 minutes).
    Use the BlueCatSession associated with $Session9 to create this record.

    A PSCustomObject representing the new TXT record will be returned (PassThru).
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new TXT record will be returned.
.LINK
    https://www.rfc-editor.org/rfc/rfc1035
    https://en.wikipedia.org/wiki/TXT_record
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('HostName','FQDN')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

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

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $FQDN = $Name | Test-ValidFQDN
        $LookupParms = @{
            Name           = $FQDN
            BlueCatSession = $BlueCatSession
        }
        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        }

        $TextInfo = Resolve-BlueCatFQDN @LookupParms

        if ($TextInfo.alias) {
            throw "Aborting TXT record creation: Alias/CName record for $($FQDN) found!"
        }

        if (-not $TextInfo.zone) {
            # No deployable zone was found for TXT record
            throw "No deployable zone was found for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Selected Zone #$($TextInfo.zone.id) as '$($TextInfo.zone.name)'"

        if ($TextInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($TextInfo.external.name)'"
        }

        $Body = @{
            type       = 'TXTRecord'
            name       = $TextInfo.shortName
            properties = "ttl=$($TTL)|absoluteName=$($TextInfo.name)|txt=$($Text.Trim('"'))|"
        }
        $CreateTXTRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($TextInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateTXTRecord
        if (-not $BlueCatReply) {
            throw "TXT record creation failed for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($TextInfo.name)'"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
