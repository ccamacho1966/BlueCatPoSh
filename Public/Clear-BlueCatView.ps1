function Clear-BlueCatView {
    [CmdletBinding()]

    param(
        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $Force
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ((-not $BlueCatSession.idView) -and (!$Force)) {
            Write-Warning "$($thisFN): View was not set. Use '-Force' to suppress this warning."
        } else {
            Write-Verbose "$($thisFN): View cleared from connection: $($BlueCatSession.Username)@$($BlueCatSession.Server)"
        }

        $BlueCatSession.idView = 0
        $BlueCatSession.View = $null
    }
}
