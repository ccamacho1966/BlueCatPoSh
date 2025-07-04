function Get-BlueCatHost {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [Parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $result = Resolve-BlueCatFQDN -BlueCatSession $BlueCatSession -FQDN $Name -Quiet

        if ($result.external) {
            Write-Warning -Message "Get-BlueCatHost: Found External Host #$($result.external.id) as '$($result.name)'"
        }

        if ($result.host) {
            $hostRec = $result.host
            $hostRec | Add-Member -MemberType NoteProperty -Name zone -Value $result.zone
            Write-Verbose "Get-BlueCatHost: Selected #$($hostRec.id) as '$($hostRec.name)' (Zone #$($hostRec.zone.id) as '$($hostRec.zone.name)')"
        } else {
            throw "No host record found for '$($result.name)'"
        }

        $hostRec
    }
}
