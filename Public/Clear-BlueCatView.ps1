function Clear-BlueCatView {
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $Force
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        if ((-not $BlueCatSession.idView) -and (!$Force)) {
            Write-Warning 'Clear-BlueCatView: View was not set. Use ''-Force'' to suppress this warning.'
        }

        $BlueCatSession.idView = 0
        $BlueCatSession.View = $null
        Write-Verbose "Clear-BlueCatView: View cleared from connection: $($BlueCatSession.Username)@$($BlueCatSession.Server)"
    }
}
