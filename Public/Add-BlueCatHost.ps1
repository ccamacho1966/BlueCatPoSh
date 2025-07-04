function Add-BlueCatHost {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name,

        [parameter(Mandatory)]
        [string[]] $Addresses, # accept one or more strings

        [int] $TTL = -1,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $HostInfo = Resolve-BlueCatFQDN -Connection $BlueCatSession -FQDN $Name
        if ($HostInfo.host) {
            # There is already a host entry!!
            Throw 'Host record already exists'
        }

        if (-not $HostInfo.zone) {
            # No deployable zone was found for Alias/CName
            throw "No deployable zone for $($Name)"
        }

        Write-Verbose "Add-BlueCatHost: Selected Zone #$($HostInfo.zone.id) as '$($HostInfo.zone.name)'"

        if ($HostInfo.external) {
            Write-Warning "Add-BlueCatHost: An external host entry exists for '$($HostInfo.external.name)'"
        }

        $ipList = $null
        foreach ($ip in $Addresses) {
            if ($ipList) {
                $ipList = $ipList+','+$ip
            } else {
                $ipList = $ip
            }
        }

        $Query = "addHostRecord?viewId=$($HostInfo.view.id)&absoluteName=$($HostInfo.name)&addresses=$($ipList)&ttl=$($TTL)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Query
        if (-not $result.id) { throw "Host creation failed for $($Name) - $($result)" }

        Write-Verbose "Add-BlueCatHost: Created #$($result.id) as '$($HostInfo.name)' (IP(s): $($ipList))"

        if ($PassThru) { Get-BlueCatHost -BlueCatSession $BlueCatSession -Name $HostInfo.name }
    }
}
