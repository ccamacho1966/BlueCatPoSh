function Connect-BlueCat {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(ValueFromPipeline,Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Credential -eq [System.Management.Automation.PSCredential]::Empty) {
            $Credential = Get-Credential -UserName $env:USERNAME -Message "Credentials for BlueCat Appliance ($($Server))"
        }

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
