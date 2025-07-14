function Add-BlueCatSRV
{
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('FQDN')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Value')]
        [string] $Target,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Port,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Priority,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Weight,

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
        $NewTarget         = $Target | Test-ValidFQDN
        $LookupTarget.Name = $NewTarget

        $targetInfo        = Resolve-BlueCatFQDN @LookupTarget
        if ($targetInfo.host) {
            $targetName = $targetInfo.host.name
            Write-Verbose "$($thisFN): Found host record for target '$($targetName)' (ID:$($targetInfo.host.id))"
            if ($targetName.external) {
                Write-Warning "$($thisFN): Both internal and external host entries found for $($targetName.host)"
            }
        } elseif ($targetInfo.external) {
            $targetName = $targetInfo.external.name
            Write-Verbose "$($thisFN): Found EXTERNAL host record for target '$($targetName)' (ID:$($targetInfo.external.id))"
        } else {
            throw "Aborting SRV record creation: No host record found for target $($NewTarget)"
        }

        $Body = @{
            type       = 'SRVRecord'
            name       = $SRVInfo.shortName
            properties = "ttl=$($TTL)|absoluteName=$($SRVInfo.name)|linkedRecordName=$($NewTarget)|port=$($Port)|priority=$($Priority)|weight=$($Weight)|"
        }
        $CreateSRVRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($SRVInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateSRVRecord
        if (-not $BlueCatReply) {
            throw "SRV record creation failed for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($SRVInfo.name)' (points to $($targetName):$($Port) priority:$($Priority) weight:$($Weight))"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
