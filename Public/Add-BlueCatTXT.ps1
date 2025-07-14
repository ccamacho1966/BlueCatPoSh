function Add-BlueCatTXT
{
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
