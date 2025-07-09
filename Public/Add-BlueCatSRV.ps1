function Add-BlueCatSRV {
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [Alias('FQDN')]
        [string] $Name,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Port,

        [parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Priority,

        [parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Weight,

        [int] $TTL, # = -1,

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

        $FQDN = $Name.TrimEnd('\.')
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

        $SRVInfo = Resolve-BlueCatFQDN @LookupParms

        # Insert check for duplicate/conflicting specific SRV record

        if ($SRVInfo.alias) {
            throw "Aborting SRV record creation: Alias/CName record for $($FQDN) found!"
        }

        if (-not $SRVInfo.zone) {
            # No deployable zone was found for SRV record
            throw "No deployable zone was found for $($FQDN)"
        }
        Write-Verbose "$($thisFN): Selected Zone #$($SRVInfo.zone.id) as '$($SRVInfo.zone.name)'"

        if ($SRVInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($SRVInfo.external.name)'"
        }

        $LookupTarget      = $LookupParms
        $NewTarget         = $Target.TrimEnd('\.')
        $LookupTarget.Name = $NewTarget
        $targetInfo        = Resolve-BlueCatFQDN @LookupRelay
        if ($targetInfo.host) {
            $targetName = $targetInfo.host.name
            if ($targetName.external) {
                Write-Warning "$($thisFN): Both internal and external host entries found for $($targetName.host)"
            }
        } elseif ($targetInfo.external) {
            $targetName = $targetInfo.external.name
        } else {
            throw "Aborting SRV record creation: No host record found for target $($NewTarget)"
        }

        if ($SRVInfo.shortName) {
            $SRVName = $SRVInfo.name
        } else {
            $SRVName = '.'+$SRVInfo.name
        }

        $Uri = "addSRVRecord?viewId=$($SRVInfo.view.id)&absoluteName=$($SRVName)&linkedRecordName=$($targetName)&port=$($Port)&priority=$($Priority)&weight=$($Weight)"
        if ($TTL) {
            $Uri += "&ttl=$($TTL)"
        }
        $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Uri
        if (-not $BlueCatReply) { throw "SRV creation failed for $($FQDN) - $($BlueCatReply)" }

        Write-Verbose "$($thisFN): Created SRV #$($BlueCatReply) for '$($SRVInfo.name)' (points to $($targetName) priority $($Priority))"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
