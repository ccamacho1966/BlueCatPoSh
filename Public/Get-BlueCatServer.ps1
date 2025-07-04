Function Get-BlueCatServer {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Server','HostName')]
        [string] $Name,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $BlueCatSession | Confirm-Settings -Config

        $Query = "getEntityByName?parentId=$($BlueCatSession.idConfig)&type=Server&name=$($Name)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        if (-not $result.id) { throw "Server '$($Name)' not found!" }

        $sObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        Write-Verbose "Get-BlueCatServer: Selected #$($sObj.id) as '$($sObj.name)'"

        $Query = "getEntities?parentId=$($sObj.id)&type=PublishedServerInterface&start=0&count=10"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

        if (-not $result.Count) {
            # This server has no published interfaces
            Write-Verbose "Get-BlueCatServer: No published interface found for '$($sObj.name)'"
            $intArray = $null
        } else {
            $intArray = @()
            foreach ($bit in $result.SyncRoot) {
                $intEntry = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "Get-BlueCatServer: Published Interface #$($intEntry.id) as '$($intEntry.name)' for '$($sObj.name)'"
                $intArray += $intEntry
            }
        }
        $sObj | Add-Member -MemberType NoteProperty -Name published -Value $intArray

        $Query = "getEntities?parentId=$($sObj.id)&type=NetworkServerInterface&start=0&count=10"
        try {
            $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        } catch {  }

        # This server has no interfaces
        if (-not $result.Count) {
            $intArray = $null
        } else {
            $intArray = @()
            foreach ($bit in $result.SyncRoot) {
                $intEntry = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "BlueCat: Get-Server: Found Interface #$($intEntry.id) as '$($intEntry.name)' for '$($sObj.name)'"
                $intArray += $intEntry
            }
        }
        $sObj | Add-Member -MemberType NoteProperty -Name interface -Value $intArray

        $sObj
    }
}
