function Clear-BlueCatConfig {
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch]$Force
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        if ((-not $BlueCatSession.idConfig) -and (!$Force)) {
            Write-Warning 'Clear-BlueCatConfig: Config was not set. Use ''-Force'' to suppress this warning.'
        }

        if ($BlueCatSession.idView) { $BlueCatSession | Clear-BlueCatView }

        $BlueCatSession.idConfig = 0
        $BlueCatSession.Config = $null
        Write-Verbose "Clear-BlueCatConfig: Config cleared from $($BlueCatSession.Username)@$($BlueCatSession.Server)"
    }
}
