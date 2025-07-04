Function Get-BlueCatMX {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name,

        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $BlueCatSession | Confirm-Settings -Config -View

        $ZIobj = Resolve-BlueCatFQDN -FQDN $Name -BlueCatSession $BlueCatSession

        if (!$ZIobj.zone) { throw "No deployable zone found for $($Name.TrimEnd('\.'))!" }

        $Query = "getEntitiesByName?parentId=$($ZIobj.zone.id)&type=MXRecord&start=0&count=10&name=$($ZIobj.shortName)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

        if ($result.Count) {
            $MXarray = @()
            foreach ($bit in $result.SyncRoot) {
                $MXentry = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $MXentry | Add-Member -MemberType NoteProperty -Name zone -Value $ZIobj.zone
                Write-Verbose "BlueCat: Get-MX: Selected MX #$($MXentry.id) as $($MXentry.property.linkedRecordName) (Priority $($MXentry.property.priority)) for $($MXentry.name)"
                $MXarray += $MXentry
            }
            $MXobj = New-Object -TypeName psobject
            $MXobj | Add-Member -MemberType NoteProperty -Name name      -Value $Name.TrimEnd('\.')
            $MXobj | Add-Member -MemberType NoteProperty -Name type      -Value MXList
            $MXobj | Add-Member -MemberType NoteProperty -Name MXList    -Value $MXarray
            $MXobj | Add-Member -MemberType NoteProperty -Name zone      -Value $ZIobj.zone
            $MXobj | Add-Member -MemberType NoteProperty -Name config    -Value $ZIobj.config
            $MXobj | Add-Member -MemberType NoteProperty -Name view      -Value $ZIobj.view
            $MXobj | Add-Member -MemberType NoteProperty -Name shortName -Value $ZIobj.shortName
            $MXobj | Add-Member -MemberType NoteProperty -Name Count     -Value $result.Count
            $MXobj | Add-Member -MemberType NoteProperty -Name Length    -Value $result.Length

            $MXobj
        }
    }
}
