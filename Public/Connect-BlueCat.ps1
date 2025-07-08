function Connect-BlueCat {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string] $Server,

        [parameter(ValueFromPipeline,Mandatory)]
        [pscredential] $Credential,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        try {
            $NewSession = [BlueCat]::new($Server, $Credential)
            Write-Verbose "$($thisFN): Logged in as $($NewSession.Username)@$($NewSession.Server) [$($NewSession.SessionStart)]"
        } catch {
            Write-Verbose "$($thisFN): Login as $($Credential.UserName)@$($Server) failed: $($_)"
            throw $_
        }

        # Update the internal list of all active BlueCat sessions
        $Script:BlueCatAllSessions += $NewSession
        if ($PassThru) {
            # Return the new session instance, but do not update the default session
            $NewSession
        } else {
            # Update the default session and return nothing
            $Script:BlueCatSession = $NewSession
        }
    }
}
