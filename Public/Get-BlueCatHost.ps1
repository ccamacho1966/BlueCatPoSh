function Get-BlueCatHost {
<#
.SYNOPSIS
    Retrieve a Host record (A/AAAA)
.DESCRIPTION
    The Get-BlueCatHost cmdlet allows the retrieval of DNS A and AAAA records.
.PARAMETER Name
    A string value representing the FQDN of the Host record to be retrieved.
.PARAMETER Zone
    An optional zone object to be searched. Providing a zone object reduces API calls making the lookup faster.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatHost -Name server1.example.com

    Returns a PSCustomObject representing the requested host record, or NULL if not found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Get-BlueCatHost -Name server9.example.com -ViewID 23456 -BlueCatSession $Session3

    Returns a PSCustomObject representing the requested host record, or NULL if not found.
    Use the BlueCatSession associated with $Session3 to perform this lookup.
    The record will be searched for in view 23456.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing the requested host record, or NULL if not found.

    [int] id
    [string] name
    [string] shortName
    [string] type = 'HostRecord'
    [string] properties
    [PSCustomObject] property
    [PSCustomObject] config
    [PSCustomObject] view
    [PSCustomObject] zone
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('HostName')]
        [string] $Name,

        [Parameter(ParameterSetName='ZoneObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Zone,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

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

        if ($Zone) {
            $View = $Zone.view
        } elseif ($ViewID) {
            $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
        } elseif (-not $View) {
            # No View or ViewID has been passed in so attempt to use the default view
            $BlueCatSession | Confirm-Settings -View
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
            $View = $BlueCatSession.View
        }

        if (-not $View) {
            throw "$($thisFN): View could not be resolved"
        }

        if (-not $View.ID) {
            # This is not a valid object!
            throw "$($thisFN): Invalid View object passed to function!"
        }

        if ($View.type -ne 'View') {
            throw "$($thisFN): Object is not a View (ID:$($View.ID) $($View.name) is a $($View.type))"
        }

        # Trim any trailing dots from the name for consistency/display purposes
        $FQDN = $Name | Test-ValidFQDN

        # Resolve zone if not provided
        if (-not $Zone) {
            $Zone = Resolve-BlueCatZone -Name $FQDN -View $View -BlueCatSession $BlueCatSession
            if (-not $Zone) {
                # Zone could not be resolved
                Write-Warning "$($thisFN): Zone could not be resolved for $($FQDN)"
            }
        }

        if ($Zone) {
            # Resolve short name for lookup
            if ($FQDN -eq $Zone.name) {
                $ShortName = ''
            } else {
                $ShortName = $FQDN -replace "\.$($Zone.name)$", ''
            }

            # Warn if a possibly conflicting external host record was also found
            $xHost = Get-BlueCatExternalHost -Name $FQDN -View $View -BlueCatSession $BlueCatSession
            if ($xHost) {
                Write-Warning "$($thisFN): Found External Host '$($xHost.name)' (ID:$($xHost.id))"
            }

            # Lookup record
            $Query = "getEntityByName?parentId=$($Zone.id)&name=$($ShortName)&type=HostRecord"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
        }

        if ($BlueCatReply.id) {
            # Build the full object
            $PropertyObj = $BlueCatReply.properties | Convert-BlueCatPropertyString
            $PropertyObj | Add-Member -MemberType NoteProperty -Name 'address' -Value ($PropertyObj.addresses -split ',')
            $HostObj     = [PSCustomObject] @{
                id         = $BlueCatReply.id
                name       = $PropertyObj.absoluteName
                type       = $BlueCatReply.type
                shortName  = $BlueCatReply.name
                address    = $PropertyObj.address
                zone       = $Zone
                property   = $PropertyObj
                properties = $BlueCatReply.properties
                view       = $View
                config     = $View.config
            }

            # Return the host object to caller
            $HostObj
        } else {
            # No object was returned
            throw "$($thisFN): No record found for $($FQDN)"
        }
    }
}
