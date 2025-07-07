function Get-BlueCatParent {
    [cmdletbinding()]

    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [Alias('EntityID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity')]
        [PSCustomObject] $Object,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if (-not $ID) {
            if (-not $Entity.id) {
                throw "$($thisFN): Invalid entity object"
            }
            $ID = $Entity.id
        }

        $Query        = "getParent?entityId=$($ID)"
        $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        if (-not $BlueCatReply.id) {
            throw "Entity Id $($ID) parent not found: $($BlueCatReply)"
        }

        Get-BlueCatEntityById -ID $BlueCatReply.id -BlueCatSession $BlueCatSession
    }
}
