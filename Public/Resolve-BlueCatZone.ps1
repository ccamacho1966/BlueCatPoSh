function Resolve-BlueCatZone {
<#
.SYNOPSIS
    Searches the View for a Deployable Zone that could contain the FQDN
.DESCRIPTION
    Resolve-BlueCatZone will attempt to find the DNS zone that could contain the supplied FQDN. The FQDN does not need to exist.
.PARAMETER Name
    A string value representing the FQDN of the record to be searched for.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.EXAMPLE
    PS> $Results = Resolve-BlueCatZone -Name 'myhostname.example.com' -View 1818 -BlueCatSession $Session19

    PS> if ($Results.host) {
            Write-Output "Found a Host record (ID:$($Results.host.id)) for $($Results.name) in zone $($Results.zone.name) (ID:$($Results.zone.id))"
        }

    Searches the BlueCat database under view 1818 using BlueCat session $Session19 for 'myhostname.example.com'
    Stores the results of the cmdlet in the variable $Results
    Test members zone, host, external, and alias to see if matching records were found.
    Directly reference the member objects for further related data.
.INPUTS
    None.
.OUTPUTS
    PSCustomObject representing the requested zone definition, or NULL if not found.

    [int] id
    [string] name
    [string] shortName
    [string] type = 'Zone'
    [string] properties
    [PSCustomObject] property
    [PSCustomObject] config
    [PSCustomObject] view
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('FQDN')]
        [string] $Name,

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

        $FQDN = $Name | Test-ValidFQDN
        Write-Verbose "$($thisFN): Map '$($FQDN)' to a Deployable Zone"

        if ($View) {
            # A view object has been passed in so test its validity
            if (-not $View.ID) {
                # This is not a valid view object!
                throw "Invalid View object passed to function!"
            }
            # Use the view ID from the View object
            $ViewID = $View.ID
        }

        if (-not $ViewID) {
            # No view ID has been passed in so attempt to use the default view
            $BlueCatSession | Confirm-Settings -View
            $ViewID = $BlueCatSession.View.id
            Write-Verbose "$($thisFN): Using default view $($BlueCatSession.View.name)"
        }

        # Set the starting point for the zone/FQDN search to the View
        $NextID = $ViewID

        # Split the FQDN into components and flip the order
        $SearchPath = $FQDN.Split('\.')
        [array]::Reverse($SearchPath)

        foreach ($bit in $SearchPath) {
            Write-Verbose "$($thisFN): Zone Trace is searching for component '$($bit)'..."

            $Query = "getEntityByName?parentId=$($NextID)&type=Zone&name=$($bit)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -Connection $BlueCatSession

            if (-not $BlueCatReply.id) {
                # Not a Zone or 'bit' doesn't exist - Stop the search
                break
            }

            # save the result in case this is the last bit of the zone path
            $LastResult = $BlueCatReply

            # update the parent to this new zone and continue processing
            $NextID = $BlueCatReply.id
        }

        if ($LastResult) {
            $Zone = $LastResult | Convert-BlueCatReply -Connection $BlueCatSession
        }

        if ($Zone.property.deployable) {
            Write-Verbose "$($thisFN): Selected Zone #$($Zone.id) as '$($Zone.name)'"
            $Zone
        } else {
            Write-Verbose "$($thisFN): No Deployable Zone found for '$($FQDN)'"
        }
    }
}
