function Add-BlueCatMX
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
        [string] $Relay,

        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Priority,

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
            Name           = $FQDN
            BlueCatSession = $BlueCatSession
        }
        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        }

        $MXInfo = Resolve-BlueCatFQDN @LookupParms

        # Insert check for duplicate/conflicting specific MX record

        if ($MXInfo.alias) {
            throw "Aborting MX record creation: Alias/CName record for $($FQDN) found!"
        }

        if (-not $MXInfo.zone) {
            # No deployable zone was found for MX record
            throw "No deployable zone was found for $($FQDN)"
        }
        Write-Verbose "$($thisFN): Selected Zone #$($MXInfo.zone.id) as '$($MXInfo.zone.name)'"

        if ($MXInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($MXInfo.external.name)'"
        }

        $LookupRelay      = $LookupParms
        $NewRelay         = $Relay | Test-ValidFQDN
        $LookupRelay.Name = $NewRelay

        $relayInfo        = Resolve-BlueCatFQDN @LookupRelay
        if ($relayInfo.host) {
            $relayName = $relayInfo.host.name
            Write-Verbose "$($thisFN): Found host record for relay '$($NewRelay)' (ID:$($relayInfo.host.id))"
            if ($relayInfo.external) {
                Write-Warning "$($thisFN): Both internal and external host entries found for $($NewRelay)"
            }
        } elseif ($relayInfo.external) {
            $relayName = $relayInfo.external.name
            Write-Verbose "$($thisFN): Found EXTERNAL host record for relay '$($NewRelay)' (ID:$($relayInfo.external.id))"
        } else {
            throw "Aborting MX record creation: No host record found for relay $($NewRelay)"
        }

        $Body = @{
            type       = 'MXRecord'
            name       = $MXInfo.shortName
            properties = "ttl=$($TTL)|absoluteName=$($MXInfo.name)|linkedRecordName=$($relayName)|priority=$($Priority)|"
        }
        $CreateMXRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($MXInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateMXRecord
        if (-not $BlueCatReply) {
            throw "MX record creation failed for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($MXInfo.name)' (points to $($relayName) priority:$($Priority))"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
