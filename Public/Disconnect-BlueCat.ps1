function Disconnect-BlueCat {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        if (-not $BlueCatSession) {
            # If we're using the default then erase the default
            $BlueCatSession = $Script:BlueCatSession
            $Script:BlueCatSession = $null
        }

        if ($BlueCatSession) {
            $Result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request 'logout'
            Write-Verbose $Result
        } else {
            Write-Verbose 'No active BlueCat session to disconnect'
        }
    }
}
