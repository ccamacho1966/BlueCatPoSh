Function Add-BlueCatDNSDeploymentRole {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [psobject] $Zone,

        [Parameter(Mandatory)]
        [psobject] $Interface,

        [Parameter(Mandatory)]
        [ValidateSet('NONE','MASTER','MASTER_HIDDEN','SLAVE','SLAVE_STEALTH','FORWARDER','STUB','RECURSION','AD_MASTER')]
        [string] $Role,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $BlueCatSession | Confirm-Settings -Config

        $Uri = "addDNSDeploymentRole?entityId=$($Zone.id)&serverInterfaceId=$($Interface.id)&type=$($Role)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Uri
        if (-not $result) { throw "Add-BlueCatDNSDeploymentRole: FAIL [$($result)]" }

        Write-Verbose "Add-BlueCatDNSDeploymentRole: Success! [$($result)]"
    }
}
