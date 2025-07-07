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
        $thisFN = (Get-PSCallStack)[0].Command

        if ((-not $BlueCatSession.idConfig) -and (!$Force)) {
            Write-Warning "$($thisFN): Config was not set. Use '-Force' to suppress this warning."
        } else {
            Write-Verbose "$($thisFN): Config cleared from $($BlueCatSession.Username)@$($BlueCatSession.Server)"
        }

        $BlueCatSession.idConfig = 0
        $BlueCatSession.Config = $null

        if ($BlueCatSession.idView) { $BlueCatSession | Clear-BlueCatView }
    }
}
