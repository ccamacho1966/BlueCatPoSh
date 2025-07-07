function Add-BlueCatExternalHost {
    [cmdletbinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [Alias('ExternalHost')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [PSCustomObject] $Properties,

        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $xHost = $Name.TrimEnd('\.')
        $LookupParms = @{
            Name           = $xHost
            BlueCatSession = $BlueCatSession
        }
        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        }

        $BlueCatReply = Get-BlueCatExternalHost @LookupParms
        if ($BlueCatReply) {
            throw "$($thisFN): $($xHost) already exists as Object #$($result.id)!"
        }

        $Uri = "addExternalHostRecord?viewId=$($ViewID)&name=$($xHost)"
        $BlueCatReply = Invoke-BlueCatApi -Method Post -Request $Uri -Connection $BlueCatSession
        if (!$BlueCatReply) {
            throw "$($thisFN): Failed to create $($xHost): $($result)"
        }

        Write-Verbose "$($thisFN): Created #$($result) as '$($xHost)'"

        if ($PassThru) { Get-BlueCatExternalHost @LookupParms }
    }
}
