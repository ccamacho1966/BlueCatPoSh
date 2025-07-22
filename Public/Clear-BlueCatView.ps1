function Clear-BlueCatView {
<#
.SYNOPSIS
    Clear the default view for a BlueCat session.
.DESCRIPTION
    The Clear-BlueCatView cmdlet will clear the default view associated with the supplied BlueCat session object.

    If no default view has been set a warning will be issued, but execution will continue.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be modified.
.PARAMETER Force
    A switch that will suppress the warning if a default view has not been set.
.EXAMPLE
    PS> Clear-BlueCatView

    Clears the default view for the default BlueCat session.
.EXAMPLE
    PS> Clear-BlueCatView -BlueCatSession $Session6

    Clears the default view for the BlueCat session associated with $Session6.
.EXAMPLE
    PS> $Session9 | Clear-BlueCatView

    Clears the default view for the BlueCat session passed to the cmdlet via the pipeline.
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

        if ((-not $BlueCatSession.View) -and (!$Force)) {
            Write-Warning "$($thisFN): View was not set. Use '-Force' to suppress this warning."
        } else {
            Write-Verbose "$($thisFN): Cleared default view $($BlueCatSession.View.name) (ID:$($BlueCatSession.View.id)) from session $($BlueCatSession.Username)@$($BlueCatSession.Server)"
        }

        $BlueCatSession.View = $null
    }
}
