function Add-BlueCatHost
{
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name,

        [parameter(Mandatory)]
        [string[]] $Addresses, # accept one or more strings

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

        $NewHost = $Name | Test-ValidFQDN
        $LookupParms = @{
            Name           = $NewHost
            BlueCatSession = $BlueCatSession
        }

        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        }

        $HostInfo = Resolve-BlueCatFQDN @LookupParms
        if ($HostInfo.host) {
            # There is already a host entry!!
            throw 'Host record already exists'
        }

        if (-not $HostInfo.zone) {
            # No deployable zone was found for Alias/CName
            throw "No deployable zone for $($NewHost)"
        }

        Write-Verbose "$($thisFN): Selected Zone #$($HostInfo.zone.id) as '$($HostInfo.zone.name)'"

        if ($HostInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($HostInfo.external.name)'"
        }

        $ipList = $null
        foreach ($ip in $Addresses) {
            if ($ipList) {
                $ipList = $ipList+','+$ip
            } else {
                $ipList = $ip
            }
        }

        $Body = @{
            type       = 'HostRecord'
            name       = $HostInfo.shortName
            properties = "ttl=$($TTL)|absoluteName=$($SRVInfo.name)|addresses=$($ipList)|reverseRecord=true|"
        }
        $CreateHostRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($HostInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateHostRecord
        if (-not $BlueCatReply) {
            throw "Host creation failed for $($NewHost)"
        }

        Write-Verbose "$($thisFN): Created Host Record for '$($HostInfo.name)' - ID:$($($BlueCatReply)), IP(s): $($ipList)"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
