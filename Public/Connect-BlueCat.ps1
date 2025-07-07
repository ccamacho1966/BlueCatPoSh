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
            $result = [BlueCat]::new($Server, $Credential)
            Write-Verbose "$($thisFN): Logged in as $($result.Username)@$($result.Server) [$($result.SessionStart)]"
        } catch {
            Write-Verbose "$($thisFN): Login as $($Credential.UserName)@$($Server) failed: $($_)"
            throw $_
        }

        if ($PassThru) {
            $result
        } else {
            $Script:BlueCatSession = $result
        }
    }
}
