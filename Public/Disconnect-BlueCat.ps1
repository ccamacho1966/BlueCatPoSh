function Disconnect-BlueCat {
    [CmdletBinding()]

    param(
        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if (-not $BlueCatSession) {
            # If we're using the default then erase the default
            $BlueCatSession = $Script:BlueCatSession
            $Script:BlueCatSession = $null
        }

        if ($BlueCatSession) {
            # Remove this session for the internal list of active BlueCat sessions
            [BlueCat[]] $Script:BlueCatAllSessions = $Script:BlueCatAllSessions | Where-Object -Property 'idTag' -NE -Value $BlueCatSession.idTag

            # Invoke the API logout endpoint, but do not trigger an error if it fails
            $Result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request 'logout'
            Write-Verbose "$($thisFN): $($Result)"
        } else {
            Write-Verbose "$($thisFN): No active BlueCat session to disconnect"
        }
    }
}
