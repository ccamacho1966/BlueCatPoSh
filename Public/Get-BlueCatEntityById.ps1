function Get-BlueCatEntityById {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(Mandatory)]
        [Alias('EntityID')]
        [int] $ID
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $Query = "getEntityById?id=$($ID)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        if ($result.id -eq 0) {
            Write-Verbose "Get-BlueCatEntityById: ID #$($ID) not found: $($result)"
            throw "Entity Id $($ID) not found: $($result)"
        }

        $objConfig = $objView = $null
        if ($result.type -ne 'Configuration') {
            $objConfig = Trace-BlueCatConfigFor -ID $ID -Connection $BlueCatSession
            if (($result.type -ne 'View') -and ($result.type -notmatch '^IP4[BNA].*')) {
                $objView = Trace-BlueCatViewFor -ID $ID -Connection $BlueCatSession
            }
        }

        $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession -Configuration $objConfig -View $objView
    }
}
