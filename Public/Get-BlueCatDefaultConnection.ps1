function Get-BlueCatDefaultConnection {
    [cmdletbinding()]

    param( )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Script:BlueCatSession.Server) {
            Write-Verbose "$($thisFN): $($Script:BlueCatSession.Username)@$($Script:BlueCatSession.Server)"
            $Script:BlueCatSession
        } else {
            Write-Verbose "$($thisFN): NO DEFAULT SESSION"
        }
    }
}
