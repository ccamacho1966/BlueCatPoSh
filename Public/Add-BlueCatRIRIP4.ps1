function Add-BlueCatRIRIP4 {
    [CmdletBinding()]

    Param(
        [parameter(Mandatory)]
        [string] $Address,

        [ValidateSet('ARIN','Other')]
        [Alias('RIR')]
        [string] $Registry = 'ARIN',

        [Parameter(ParameterSetName='ByObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Config,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByName')]
        [string] $ConfigName,

        [Parameter(Mandatory,Position=0,ParameterSetName='ByID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ConfigID,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        ### Validate/Find the Config object here

        $BlueCatContainer = Get-BlueCatIPContainerByIP -Parent $Config -Address $Address -BlueCatSession $BlueCatSession
        if ($BlueCatContainer.type -eq 'IP4Network') {
            Write-Warning "$($thisFN): IP4Network already exists"
            if ($PassThru) {
                $BlueCatContainer
            }
            return
        }

        if ($Registry -eq 'ARIN') {
            $RdapUri = "https://rdap.arin.net/registry/ip/$($Address)"
        } elseif ($Registry -eq 'XYX') {
            $RdapUri = "https://rdap.local/registry/ip/$($Address)"
        } else {
            throw "$($thisFN): Unknown registry '$($Registry)'"
        }

        $RdapInfo = Invoke-RestMethod -Method Get -Uri $RdapUri

        # Build possible new block and missing network(s) from RDAP information
        if ($RdapInfo.cidr0_cidrs.Count -eq 0) {
            throw "$($thisFN): Could not retrieve IP network info for $($Address)"
        } elseif ($RdapInfo.cidr0_cidrs.Count -eq 1) {
            # One CIDR means the block and network should match
            $CIDRspec = "$($RdapInfo.cidr0_cidrs[0].v4prefix)/$($RdapInfo.cidr0_cidrs[0].length)"
            $NewBlock = @{
                CIDR  = $CIDRspec
            }
            [string[]] $NewNetwork = @($CIDRspec)
        } else {
            # Multiple CIDRs means the block will need to be a range and multiple networks will need to be created
            $NewBlock = @{
                StartAddress = $RdapInfo.startAddress
                EndAddress   = $RdapInfo.endAddress
            }
            [string[]] $NewNetwork = @()
            foreach ($netEntry in $RdapInfo.cidr0_cidrs) {
                $CIDRspec    = "$($netEntry.v4prefix)/$($netEntry.length)"
                $NewNetwork += $CIDRspec
            }
        }

        $OwnerName = $RdapInfo.entities | Get-OrgNameFromEntities
        if (-not $OwnerName) {
            # Didn't find an owner org name. Not a fatal error...
            Write-Warning "$($thisFN): Could not retrieve Owner Info for $($Address) from $($RdapUri)"
        }

        if ($BlueCatContainer) {
            Write-Verbose "$($thisFN): Selecting $($BlueCatContainer.type) '$($BlueCatContainer.name)' (ID:$($BlueCatContainer.id))"
            $IPblock = $BlueCatContainer
        } else {
            # Create a new IP4Block
            $NewBlockParms = @{
                Name           = $OwnerName
                Parent         = $Config.id
                PassThru       = $true
                BlueCatSession = $BlueCatSession
            }

            if ($NewBlock.CIDR) {
                # Include CIDR spec for a CIDR block
                $NewBlockParms.CIDR  = $NewBlock.CIDR
                $IpSpec              = $NewBlock.CIDR
            } else {
                # Include start and end addresses for a Range block
                $NewBlockParms.Start = $NewBlock.StartAddress
                $NewBlockParms.End   = $NewBlock.EndAddress
                $IpSpec              = "$($NewBlock.StartAddress) - $($NewBlock.EndAddress)"
            }

            # Create and announce new IP4 block
            $IPblock = Add-BlueCatIP4Block @NewBlockParms
            Write-Output "$($thisFN): Created ID:$($IPblock.id) IP4Block '$($IPblock.name)' ($($IpSpec))"
        }

        # Create the new IP network(s)
        $PropertyFields = [PsCustomObject] @{ name = $OwnerName }
        foreach ($netEntry in $NewNetwork) {
            $NewNetworkParms = $bcSession + @{
                Parent         = $IPblock.id
                CIDR           = $netEntry
                Property       = $PropertyFields
                PassThru       = $true
                BlueCatSession = $BlueCatSession                
            }

            # Create and announce new IP4 network
            $IPnetwork = Add-BlueCatIP4Network @NewNetworkParms
            Write-Output "$($thisFN): Created ID:$($IPnetwork.id) IP4Network '$($IPnetwork.name)' ($($netEntry))"
        }

        if ($PassThru) {
            Get-BlueCatIPContainerByIP -Parent $Config -Address $Address -BlueCatSession $BlueCatSession
        }
    }
}
