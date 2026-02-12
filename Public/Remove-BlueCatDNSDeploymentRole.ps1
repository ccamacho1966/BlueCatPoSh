function Remove-BlueCatDNSDeploymentRole {
<#
.SYNOPSIS
    Remove a BlueCat DNS Deployment Role
.DESCRIPTION
    The Remove-BlueCatDNSDeploymentRole cmdlet allows the removal of a DNS Deployment Role.
.PARAMETER Role
    PSCustomObject representing the DNS Deployment Role to be deleted.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this operation.
.EXAMPLE
    PS> Remove-BlueCatDNSDeploymentRole -Role $DnsRole
.EXAMPLE
    PS> $DnsRole | Remove-BlueCatDNSDeploymentRole
.INPUTS
    PSCustomObject representing a DNS Deployment Role
.OUTPUTS
    None
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Role,

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

        if ($Role.type -ne 'DeploymentRole') {
            throw "$($thisFN): Object is not a Deployment Role (ID:$($Role.ID) $($Role.name) is a $($Role.type))"
        }

        $DeleteRole = @{
            Method         = 'Delete'
            Request        = "deleteDNSDeploymentRole?entityId=$($Role.entityId)&serverInterfaceId=$($Role.serverInterfaceId)"
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @DeleteRole

        if ($BlueCatReply) {
            Write-Warning "$($thisFN): Unexpected reply: $($BlueCatReply)"
        }
    }
}
