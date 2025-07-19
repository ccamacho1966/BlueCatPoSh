function Add-BlueCatZone
{
<#
.SYNOPSIS
    Create a new DNS zone.
.DESCRIPTION
    The Add-BlueCatZone cmdlet will create a new DNS zone under an existing DNS View.
.PARAMETER Name
    A string value representing the FQDN of the new DNS Zone.
.PARAMETER NotDeployable
    A switch that indicates the new DNS Zone should NOT be deployed.

    By default, newly created zones are configured to be deployable. This switch allows you to override that default.
.PARAMETER Property
    A PSCustomObject representing the DNS Zone object properties.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new DNS Zone to be returned.
.EXAMPLE
.EXAMPLE
.INPUTS
.OUTPUTS
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [Alias('Zone')]
        [string] $Name,

        [switch] $NotDeployable,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Properties')]
        [PSCustomObject] $Property,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $NewZone = $Name | Test-ValidFQDN
        $LookupParms = @{
            Name           = $NewZone
            BlueCatSession = $BlueCatSession
        }

        if ($ViewID) {
            $View             = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
            $LookupParms.View = $View
        } elseif ($View)   {
            $LookupParms.View = $View
            $ViewID           = $View.ID
        } else {
            $BlueCatSession | Confirm-Settings -View
            $View             = Get-BlueCatView -ViewID $BlueCatSession.idView -BlueCatSession $BlueCatSession
            $ViewID           = $View.ID
            $LookupParms.View = $View
        }

        Write-Verbose "$($thisFN): Create new zone $($Name) in View $($View.Name) under Configuration $($View.Config.Name)"

        try {
            $ZoneCheck = Get-BlueCatZone @LookupParms
        } catch {
            # This is what we want - Zone not found
        }
        if ($ZoneCheck) {
            throw "Zone $($ZoneCheck.name) already exists"
        }

        if ($Property) {
            if ($Property.PSObject.Properties.Name -contains 'deployable') {
                # The 'deployable' member already exists in supplied Property object...
                if ($Property.deployable -and $NotDeployable) {
                    # Property object says deployable, but -NotDeployable switch was set
                    Write-Warning "$($thisFN): Overwriting Property.deployable (-NotDeployable was requested)"
                    $Property.deployable = $false
                }
            } else {
                # The 'deployable' member doesn't exist so create a new member
                $Property | Add-Member -MemberType NoteProperty -Name 'deployable' -Value ([bool] (-not $NotDeployable))
            }
        } else {
            # No property object was supplied by the caller
            $Property = [PSCustomObject] @{
                deployable = ([bool] (-not $NotDeployable))
            }
        }

        $PropertyString = $Property | Convert-BlueCatPropertyObject

        $CreateZone = @{
            Method         = 'Post'
            Request        = "addZone?parentId=$($ViewID)&absoluteName=$($NewZone)&properties=$($PropertyString)"
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateZone
        if (-not $BlueCatReply) {
            throw "Host creation failed for $($NewHost) - $($BlueCatReply)"
        }

        Write-Verbose "$($thisFN): Created new zone $($NewZone) in View $($View.Name) under Configuration $($View.Config.Name) (ID:$($BlueCatReply))"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
