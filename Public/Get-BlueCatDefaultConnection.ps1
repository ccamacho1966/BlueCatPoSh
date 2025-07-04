function Get-BlueCatDefaultConnection {
    [cmdletbinding()]
    param( )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        Write-Verbose "Get-BlueCatDefaultConnection: $($Script:BlueCatSession.Username)@$($Script:BlueCatSession.Server)"
        $Script:BlueCatSession
    }
}
