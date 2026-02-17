function Invoke-BlueCatDeployServer {
        [CmdletBinding()]

    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Server,

        [Parameter()]
        [ValidateSet('DNS','DHCP','DHCPv6','TFTP')]
        [string[]] $Services,

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

        if ($Server.type -ne 'Server') {
            throw "$($thisFN): Object is not a Server (ID:$($Server.ID) $($Server.name) is a $($Server.type))"
        }

        $InvokeParms = @{
            Method         = 'Post'
            BlueCatSession = $BlueCatSession
        }
        if ($Services) {
            $InvokeParms.Request = "deployServerServices?serverId=$($Server.id)&services=$($Services -join ',')"
        } else {
            $InvokeParms.Request = "deployServer?serverId=$($Server.id)"
        }

        try {
            $BlueCatReply = Invoke-BlueCatApi @InvokeParms
        } catch {
            throw "$($thisFN): Server Deployment failed"
        }

        if ($BlueCatReply) {
            Write-Warning "$($thisFN): Unexpected reply: $($BlueCatReply)"
        }
    }
}
