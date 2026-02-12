Function Get-BlueCatDNSDeploymentRoles {
        [CmdletBinding()]

    param(
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Zone,

        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Zone.type -ne 'Zone') {
            throw "$($thisFN): Object is not a Zone (ID:$($Zone.ID) $($Zone.name) is a $($Zone.type))"
        }

        $LookupParms = @{
            Method         = 'Get'
            Request        = "getDeploymentRoles?entityId=$($Zone.id)"
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = [PsCustomObject[]] (Invoke-BlueCatApi @LookupParms)
        [PsCustomObject[]] $DeploymentRoles = @()
        foreach ($role in $BlueCatReply) {
            $role | Add-Member -MemberType NoteProperty -Name property -Value ($role.properties | Convert-BlueCatPropertyString)
            $role | Add-Member -MemberType NoteProperty -Name role     -Value $role.type
            $role.type = 'DeploymentRole'

            $DeploymentRoles += $role
        }

        $DeploymentRoles
    }
}
