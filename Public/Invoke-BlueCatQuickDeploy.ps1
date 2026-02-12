function Invoke-BlueCatQuickDeploy {
    [CmdletBinding()]

    param(
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Zone,

        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Zone.type -ne 'Zone') {
            throw "$($thisFN): Object is not a Zone (ID:$($Zone.ID) $($Zone.name) is a $($Zone.type))"
        }

        $InvokeParms = @{
            Method         = 'Post'
            Request        = "quickDeploy?entityId=$($Zone.id)"
            BlueCatSession = $BlueCatSession
        }

        try {
            $BlueCatReply = Invoke-BlueCatApi @InvokeParms
        } catch {
            throw "$($thisFN): Quick Deploy failed"
        }

        if ($BlueCatReply) {
            Write-Warning "$($thisFN): Unexpected reply: $($BlueCatReply)"
        }
    }
}
