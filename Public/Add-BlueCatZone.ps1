function Add-BlueCatZone {
    [cmdletbinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [Alias('Zone')]
        [string] $Name,

        [switch] $NotDeployable,

        [PSCustomObject] $Properties,

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

        $NewZone = $Name.TrimEnd('\.')
        $LookupParms = @{
            Name           = $NewZone
            BlueCatSession = $BlueCatSession
        }
        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        } else {
            $BlueCatSession | Confirm-Settings -View
            $ViewID             = $BlueCatSession.idView
            $LookupParms.ViewID = $ViewID
        }

        try {
            $ZoneCheck = Get-BlueCatZone @LookupParms
        } catch {
            # This is what we want - Zone not found
        }
        if ($ZoneCheck) {
            throw "Zone $($ZoneCheck.name) already exists"
        }

        if ($NotDeployable) {
            $propString='deployable=false|'
        } else {
            $propString='deployable=true|'
        }

        $Uri = "addZone?parentId=$($ViewID)&absoluteName=$($NewZone)&properties=$($propString)"
        $BlueCatReply = Invoke-BlueCatApi -Method Post -Request $Uri -BlueCatSession $BlueCatSession

        if (-not $BlueCatReply) {
            throw "Host creation failed for $($NewHost) - $($BlueCatReply)"
        }

        Write-Verbose "$($thisFN): Created #$($BlueCatReply) as '$($NewZone)'"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
