function Get-BlueCatServerDeploymentStatus {
        [CmdletBinding()]

    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Server,

        [Parameter()]
        [switch] $PassThru,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $ResultCodes = @{
            '-1' = 'Deploying'
             '0' = 'Initializing'
             '1' = 'Queued'
             '2' = 'Cancelled'
             '3' = 'Failed'
             '4' = 'Not Deployed'
             '5' = 'Warning'
             '6' = 'Invalid'
             '7' = 'Success'
             '8' = 'No Recent Deployment'
        }

        if ($Server.type -ne 'Server') {
            throw "$($thisFN): Object is not a Server (ID:$($Server.ID) $($Server.name) is a $($Server.type))"
        }

        $LookupParms = @{
            Method         = 'Get'
            Request        = "getServerDeploymentStatus?serverId=$($Server.id)"
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @LookupParms

        $Server.deployStatus = @{
            Timestamp   = (Get-Date)
            Code        = $BlueCatReply
            Description = ($ResultCodes["$($BlueCatReply)"])
        }

        if ($PassThru) {
            $Server.deployStatus
        }
    }
}
