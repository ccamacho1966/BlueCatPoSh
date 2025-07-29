Function Add-BlueCatDNSDeploymentRole {
    [cmdletbinding()]

    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Zone,

        [Parameter(Mandatory)]
        [PsCustomObject] $Interface,

        [Parameter(Mandatory)]
        [ValidateSet('NONE','MASTER','MASTER_HIDDEN','SLAVE','SLAVE_STEALTH','FORWARDER','STUB','RECURSION','AD_MASTER')]
        [string] $Role,

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

        if (-not $Zone.id) {
            throw "Invalid zone object!"
        }

        if (-not $Interface.id) {
            throw "Invalid interface object!"
        }

        $Uri = "addDNSDeploymentRole?entityId=$($Zone.id)&serverInterfaceId=$($Interface.id)&type=$($Role)"
        $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Uri
        if (-not $BlueCatReply) {
            throw "Failed to add DNS Deployment Role: $($BlueCatReply)"
        }

        Write-Verbose "$($thisFN): Success: $($BlueCatReply)"
    }
}
