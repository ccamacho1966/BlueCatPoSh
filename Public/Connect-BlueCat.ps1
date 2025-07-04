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
        try {
            $result = [BlueCat]::new($Server, $Credential)
            Write-Verbose "Connect-BlueCat: Logged in as $($result.Username)@$($result.Server) [$($result.SessionStart)]"
        } catch {
            Write-Verbose "Connect-BlueCat: Login as $($Credential.UserName)@$($Server) failed: $($_)"
            throw $_
        }

        if ($PassThru) {
            $result
        } else {
            $Script:BlueCatSession = $result
        }
    }
}
