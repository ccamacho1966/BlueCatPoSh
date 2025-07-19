function Clear-BlueCatConfig {
<#
.SYNOPSIS
    Clear the default configuration for a BlueCat session.
.DESCRIPTION
    The Clear-BlueCatConfig cmdlet will clear the default configuration associated with the supplied BlueCat session object.

    If a default view is configured, it will be cleared as well.

    If no default configuration has been set a warning will be issued, but execution will continue.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be modified.
.PARAMETER Force
    A switch that will suppress the warning if a default configuration has not been set.
.EXAMPLE
    PS> Clear-BlueCatConfig

    Clears the default configuration and view for the default BlueCat session.
.EXAMPLE
    PS> Clear-BlueCatConfig -BlueCatSession $Session6

    Clears the default configuration and view for the BlueCat session associated with $Session6.
.EXAMPLE
    PS> $Session9 | Clear-BlueCatConfig

    Clears the default configuration and view for the BlueCat session passed to the cmdlet via the pipeline.
.INPUTS
    [BlueCat] object representing the session to be updated.
.OUTPUTS
    None
#>
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

        if ($BlueCatSession.idView) {
            $BlueCatSession | Clear-BlueCatView
        }

        if ((-not $BlueCatSession.idConfig) -and (!$Force)) {
            Write-Warning "$($thisFN): Config was not set. Use '-Force' to suppress this warning."
        } else {
            Write-Verbose "$($thisFN): Cleared default configuration $($BlueCatSession.Config) (ID:$($BlueCatSession.idConfig)) from session $($BlueCatSession.Username)@$($BlueCatSession.Server)"
        }

        $BlueCatSession.idConfig = 0
        $BlueCatSession.Config = $null
    }
}
