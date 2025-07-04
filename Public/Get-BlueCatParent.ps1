function Get-BlueCatParent {
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [Parameter(Mandatory)]
        [int] $ID
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $Query = "getParent?entityId=$($ID)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        if (-not $result.id) {
            throw "Entity Id $($ID) not found!"
        }

        if ($result.type -ne 'Configuration') {
            $objConfig = Trace-BluecatConfigFor -ID $ID -Connection $BlueCatSession
            if ($result.type -ne 'View') {
                $objView = Trace-BlueCatViewFor -ID $ID -Connection $BlueCatSession
            }
        }

        $convertParms = @{ BlueCatSession = $BlueCatSession }
        if ($objConfig) { $convertParms.Configuration = $objConfig }
        if ($objView)   { $convertParms.View          = $objView   }
        $result | Convert-BlueCatReply @convertParms
    }
}
