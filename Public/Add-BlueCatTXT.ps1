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
.PARAMETER Zone
    An optional zone object to be searched. Providing a zone object reduces API calls making the lookup faster.
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

        [Parameter(ParameterSetName='ZoneObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Zone,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
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

        if ($Zone) {
            $View = $Zone.view
        } elseif ($ViewID) {
            $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
        } elseif (-not $View) {
            # No View or ViewID has been passed in so attempt to use the default view
            $BlueCatSession | Confirm-Settings -View
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
            $View = $BlueCatSession.View
        }

        if (-not $View) {
            throw "$($thisFN): View could not be resolved"
        }

        if (-not $View.ID) {
            # This is not a valid object!
            throw "$($thisFN): Invalid View object passed to function!"
        }

        if ($View.type -ne 'View') {
            throw "$($thisFN): Object is not a View (ID:$($View.ID) $($View.name) is a $($View.type))"
        }

        # Trim any trailing dots from the name for consistency/display purposes
        $FQDN = $Name | Test-ValidFQDN

        # Resolve zone if not provided
        if (-not $Zone) {
            $Zone = Resolve-BlueCatZone -Name $FQDN -View $View -BlueCatSession $BlueCatSession
            if (-not $Zone) {
                # Zone could not be resolved
                throw "$($thisFN): Zone could not be resolved for $($FQDN)"
            }
        }

        # Resolve short name for lookup
        if ($FQDN -eq $Zone.name) {
            $ShortName = ''
        } else {
            $ShortName = $FQDN -replace "\.$($Zone.name)$", ''
        }

        $LookupBase = @{
            Name           = $FQDN
            BlueCatSession = $BlueCatSession
            ErrorAction    = 'SilentlyContinue'
        }
        $LookupZone = $LookupBase + @{ Zone = $Zone; SkipExternalHostCheck = $true }
        $LookupView = $LookupBase + @{ View = $View }

        if (Get-BlueCatAlias @LookupZone) {
            # There is already an existing alias
            throw "$($thisFN): Existing alias record found - aborting TXT creation!"
        }

        $ExistingExternal = Get-BlueCatExternalHost @LookupView
        if ($ExistingExternal) {
            Write-Warning "$($thisFN): An external host entry exists for '$($ExistingExternal.name)' (ID:$($ExistingExternal.id))"
        }

        # Insert check for duplicate / conflicting entries

        $Body = @{
            type       = 'TXTRecord'
            name       = $ShortName
            properties = "ttl=$($TTL)|absoluteName=$($FQDN)|txt=$($Text.Trim('"'))|"
        }
        $CreateTXTRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($Zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateTXTRecord

        if ($BlueCatReply) {
            Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($FQDN)'"

            if ($PassThru) {
                # Must pull record by ID since there can be multiple records
                Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
            }
        } else {
            $Failure = "$($thisFN): Record creation failed for $($FQDN)"
            throw $Failure
            Write-Verbose $Failure
        }
    }
}
