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
    PS> Add-BlueCatZone -Name 'example.com'

    Create a new DNS zone: example.com
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Add-BlueCatZone -Name 'another.com' -ViewID 1515 -BlueCatSession $Session7 -PassThru

    Create a new DNS zone another.com using view 1515.
    Use the BlueCat session associated with $Session7 to create the zone.

    A PSCustomObject representing the new zone will be returned (PassThru).
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new zone will be returned.
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

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($ViewID) {
            $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
        } elseif (-not $View)   {
            $BlueCatSession | Confirm-Settings -View
            $View = $BlueCatSession.View
        }

        $FQDN = $Name | Test-ValidFQDN

        $LookupParms = @{
            Name           = $FQDN
            View           = $View
            BlueCatSession = $BlueCatSession
            ErrorAction    = 'SilentlyContinue'
        }

        Write-Verbose "$($thisFN): Create new zone $($FQDN) in View $($View.Name) under Configuration $($View.Config.Name)"

        try {
            $ExistingZone = Get-BlueCatZone @LookupParms
        } catch {
            # zone not found - continue processing
        }
        if ($ExistingZone) {
            $Failure = "$($thisFN): Zone $($FQDN) already exists"
            throw $Failure
            Write-Verbose $Failure
            return
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
            Request        = "addZone?parentId=$($View.id)&absoluteName=$($FQDN)&properties=$([uri]::EscapeDataString($PropertyString))"
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateZone

        if ($BlueCatReply) {
            Write-Verbose "$($thisFN): Created new zone $($FQDN) in View $($View.Name) under Configuration $($View.Config.Name) (ID:$($BlueCatReply))"

            if ($PassThru) {
                Get-BlueCatZone -Name $FQDN -View $View -BlueCatSession $BlueCatSession
            }
        } else {
            $Failure = "$($thisFN): Zone creation failed for $($FQDN)"
            throw $Failure
            Write-Verbose $Failure
        }
    }
}
