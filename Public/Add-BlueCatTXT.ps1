function Add-BlueCatTXT {
    [cmdletbinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [Alias('HostName','FQDN')]
        [string] $Name,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

        [int] $TTL = -1,

        [Parameter(ParameterSetName='ViewID')]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch]$PassThru
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
            Write-Warning "Add-BlueCatTXT: An external host entry exists for '$($TextInfo.external.name)'"
        }

        $CreateTXTRecord = @{
            Method         = 'Post'
            BlueCatSession = $BlueCatSession
        }
        if ($TextInfo.shortName) {
            $Body = @{
                type       = 'TXTRecord'
                name       = $TextInfo.shortName
                properties = "ttl=$($TTL)|absoluteName=$($TextInfo.name)|txt=$($Text.Trim('"'))|"
            }
            $CreateTXTRecord.Body = $Body | ConvertTo-Json
            $Uri = "addEntity?parentId=$($TextInfo.zone.id)"
        } else {
            $TextName   = '.'+$TextInfo.name
            $TextString = [uri]::EscapeDataString($Text.Trim('"'))
            $Uri        = "addTXTRecord?viewId=$($TextInfo.view.id)&absoluteName=$($TextName)&txt=$($TextString)&ttl=$($TTL)"
        }
        $CreateTXTRecord.Request = $Uri

        $BlueCatReply = Invoke-BlueCatApi @CreateTXTRecord
        if (-not $BlueCatReply) {
            throw "TXT creation failed for $($FQDN) - $($BlueCatReply)"
        }

        Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($TextInfo.name)'"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
