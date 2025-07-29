Function Get-BlueCatServer {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Server','HostName')]
        [string] $Name,

        [Parameter(ParameterSetName='ConfigID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ConfigID,

        [Parameter(ParameterSetName='ConfigObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Config,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Config.ID) {
            # Use the Config ID supplied with the object
            $ConfigID = $Config.ID
        }
        if (-not $ConfigID) {
            # No Config ID or Object was supplied so try to use the session default
            $BlueCatSession | Confirm-Settings -Config
            $ConfigID = $BlueCatSession.Config.id
        }

        $Query = "getEntityByName?parentId=$($ConfigID)&type=Server&name=$($Name)"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
        if (-not $BlueCatReply.id) {
            throw "Server '$($Name)' not found!"
        }

        $ServerObj = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        Write-Verbose "$($thisFN): Selected #$($ServerObj.id) as '$($ServerObj.name)'"

        # Pull a list of up to 10 published interfaces for this server
        $Query = "getEntities?parentId=$($ServerObj.id)&type=PublishedServerInterface&start=0&count=10"
        try {
            [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        } catch {
            # Continue processing
        }

        if (-not $BlueCatReply.Count) {
            # This server has no published interfaces
            Write-Verbose "$($thisFN): No published interfaces found for '$($ServerObj.name)'"
            $Published = $null
        } else {
            $Published = @()
            foreach ($RawEntry in $BlueCatReply) {
                $PubEntry = $RawEntry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "$($thisFN): Published Interface #$($PubEntry.id) as '$($PubEntry.name)' for '$($ServerObj.name)'"
                $Published += $PubEntry
            }
        }
        $ServerObj | Add-Member -MemberType NoteProperty -Name published -Value $Published

        # Pull a list of up to 10 network interfaces for this server
        $Query = "getEntities?parentId=$($ServerObj.id)&type=NetworkServerInterface&start=0&count=10"
        try {
            [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        } catch {
            # Continue processing
        }

        if (-not $BlueCatReply.Count) {
            # This server has no interfaces
            Write-Verbose "$($thisFN): No network interfaces found for '$($ServerObj.name)'"
            $Interfaces = $null
        } else {
            $Interfaces = @()
            foreach ($RawEntry in $BlueCatReply) {
                $IntfEntry = $RawEntry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                Write-Verbose "BlueCat: Get-Server: Found Interface #$($IntfEntry.id) as '$($IntfEntry.name)' for '$($ServerObj.name)'"
                $Interfaces += $IntfEntry
            }
        }
        $ServerObj | Add-Member -MemberType NoteProperty -Name interface -Value $Interfaces

        $ServerObj
    }
}
