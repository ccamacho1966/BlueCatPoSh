function Set-BlueCatDefaultConnection {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,Mandatory,Position=0)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $Script:BlueCatSession = $BlueCatSession
        Write-Verbose "Set-BlueCatDefaultConnection: $($Script:BlueCatSession.Username)@$($Script:BlueCatSession.Server)"
    }
}
