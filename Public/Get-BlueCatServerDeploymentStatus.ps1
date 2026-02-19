function Get-BlueCatServerDeploymentStatus {
<#
.SYNOPSIS
    Update a BlueCat Server object's deployStatus record
.DESCRIPTION
    The Get-BlueCatServerDeploymentStatus cmdlet updates a server object's deployStatus record.
.PARAMETER Server
    A PSCustomObject representing the server. Deployment Status is retrieved from the IPAM and the object is updated.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing only the updated Deployment Status to be returned.

    The server object will still be updated even if PassThru is specified.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatServerDeploymentStatus -Server $NameServer1

    Updates the PSCustomObject representing the server $NameServer1.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> $NameServer2 | Get-BlueCatServerDeploymentStatus -BlueCatSession $Session2

    Updates the PSCustomObject representing the server $NameServer2.
    Use the BlueCatSession associated with $Session2 to perform this lookup.
.EXAMPLE
    PS> $DeployStatus4 = $NameServer4 | Get-BlueCatServerDeploymentStatus -PassThru

    Updates the PSCustomObject representing the server $NameServer4.
    Returns a PSCustomObject representing only the updated Deployment Status which is stored in the $DeploymentStatus4 variable.
    BlueCatSession will default to the current default session.
.INPUTS
    None
.OUTPUTS
    None, by default.
    If Passthru is specified, a PSCustomObject representing the server's current deployment status is returned.

    [DateTime] Timestamp
    [int] Code
    [string] Description
#>
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
