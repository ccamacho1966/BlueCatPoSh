function Get-BlueCatEntityByName {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(Mandatory)]
        [string] $Name,

        [parameter(Mandatory)]
        [string] $EntityType,

        [Parameter()]
        [int] $ParentID
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if (-not $ParentID) {
            $BlueCatSession | Confirm-Settings -Config
            $ParentID = $BlueCatSession.idConfig
        }

        $Query = "getEntityByName?parentId=$($ParentID)&name=$($Name)&type=$($EntityType)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        if ($result.id -eq 0) {
            Throw "$($EntityType) $($Name) not found: $($result)"
        }
        Write-Verbose "Selected $($result.type) #$($result.id) as $($result.name)"

        $objConfig = $objView = $null
        if ($result.type -ne 'Configuration') {
            $objConfig = Trace-BlueCatConfigFor -id $result.id -Connection $BlueCatSession
            if (($result.type -ne 'View') -and ($result.type -notmatch '^IP4[BNA].*')) {
                $objView = Trace-BlueCatViewFor -id $result.id -Connection $BlueCatSession
            }
        }

        $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession -Configuration $objConfig -View $objView
    }
}
