function Confirm-Settings {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline,Mandatory)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession,

        [switch] $Config,

        [switch] $View
    )

    process {
        if ($Config -or $View) {
            if (-not $BlueCatSession.idConfig) {
                $testCFError = [Exception]::new('"Configuration Error: You must select a configuration before calling this command."')
                $CFErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $testCFError,
                    'ConfigNotSet',
                    [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                    $Server
                )
                throw $CFErrorRecord
            }
        }

        if ($View) {
            if (-not $BlueCatSession.idView) {
                $testCFError = [Exception]::new('"View Error: You must select a view before calling this command."')
                $CFErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $testCFError,
                    'ViewNotSet',
                    [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                    $Server
                )
                throw $CFErrorRecord
            }
        }
    }
}
