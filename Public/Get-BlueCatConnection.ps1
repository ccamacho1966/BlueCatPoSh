function Get-BlueCatConnection {
    [CmdletBinding(DefaultParameterSetName='Default')]

    param(
        [Parameter(ParameterSetName='Default')]
        [switch] $Default,

        [Parameter(ParameterSetName='All')]
        [switch] $All
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($All) {
            # Return a list of all currently active BlueCat sessions
            if ($Script:BlueCatAllSessions.Count) {
                if ($Script:BlueCatAllSessions.Count -eq 1) {
                    $s = ''
                } else {
                    $s = 's'
                }
                Write-Verbose "$($thisFN): $($Script:BlueCatAllSessions.Count) active session$($s)"

                $Script:BlueCatAllSessions
            } else {
                Write-Verbose "$($thisFN): NO ACTIVE SESSIONS"
            }
        } else {
            # Return only the current default BlueCat session
            if ($Script:BlueCatSession.Server) {
                Write-Verbose "$($thisFN): $($Script:BlueCatSession.Username)@$($Script:BlueCatSession.Server)"

                $Script:BlueCatSession
            } else {
                Write-Verbose "$($thisFN): NO DEFAULT SESSION"
            }
        }
    }
}
