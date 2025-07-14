function Set-BlueCatConnection {
    [CmdletBinding()]

    param(
        [parameter(ValueFromPipeline,Mandatory,Position=0)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $Script:BlueCatSession = $BlueCatSession
        Write-Verbose "$($thisFN): $($Script:BlueCatSession.Username)@$($Script:BlueCatSession.Server)"
    }
}
