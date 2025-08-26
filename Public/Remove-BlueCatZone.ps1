function Remove-BlueCatZone {
<#
.SYNOPSIS
    Remove a DNS Zone definition
.DESCRIPTION
    The Remove-BlueCatZone cmdlet allows the removal of DNS Zone definitions.
.PARAMETER Name
    A string value representing the FQDN of the DNS Zone to be removed.
.PARAMETER ID
    An integer value representing the entity ID of the DNS Zone to be removed.
.PARAMETER Object
    A PSCustomObject representing the DNS Zone to be removed.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object operation.
.EXAMPLE
    PS> Remove-BlueCatZone -Name example.com

    Removes the zone 'example.com' or throws an error if the zone is not found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Remove-BlueCatZone -Name anotherzone.com -ViewID 23456 -BlueCatSession $Session3

    Removes the zone 'anotherzone.com' or throws an error if the zone is not found.
    Use the BlueCatSession associated with $Session3 to perform this operation.
    The record will be searched for in view 23456.
.EXAMPLE
    PS> Remove-BlueCatZone -ID 10007

    Removes the zone with entity ID 10007 or throws an error if the zone is not found.
    BlueCatSession will default to the current default session.
    View will be automatically selected based on the entity ID.
.EXAMPLE
    PS> $ZoneObject | Remove-BlueCatZone

    Removes the zone represented by $ZoneObject which is passed on the pipeline.
    BlueCatSession will default to the current default session.
    View will be automatically selected based on the entity information.
.INPUTS
    PSCustomObject representing the zone to be removed.
.OUTPUTS
    None
#>
    [CmdletBinding(DefaultParameterSetName='byNameViewID')]

    param(
        [Parameter(ParameterSetName='byID',Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('EntityID')]
        [int] $ID,

        [Parameter(ParameterSetName='byObj',Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Entity')]
        [PSCustomObject] $Object,

        [Parameter(ParameterSetName='byNameViewID',Mandatory)]
        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ZoneName')]
        [string] $Name,

        [Parameter(ParameterSetName='byNameViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='byNameViewObj',Mandatory)]
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

        if ($ID) {
            # Convert the Entity ID into an Entity Object to use the object logic
            $Object = Get-BlueCatEntityById -ID $ID -BlueCatSession $BlueCatSession
        }

        if ($Name) {
            # Convert the Name into an Entity Object to use the object logic

            if ($ViewID) {
                # Convert the ViewID into a View Object
                $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
            } elseif (-not $View) {
                # No View ID or Object - Attempt to use the default view
                $BlueCatSession | Confirm-Settings -View
                $View = $BlueCatSession.view
                Write-Verbose "$($thisFN): Using default view '$($View.name)' (ID:$($View.id))"
            }

            # Validate the View Object
            if (-not $View.ID) {
                $FailureMessage = "$($thisFN): Invalid View Object"
                Write-Verbose $FailureMessage
                throw $FailureMessage
            }

            # Validate the View Object is the correct Entity Type
            if ($View.type -ne 'View') {
                $FailureMessage = "$($thisFN): Not a View - $($View.Name) is type '$($View.type)'"
                Write-Verbose $FailureMessage
                throw $FailureMessage
            }

            $Object = Get-BlueCatZone -Name $Name -View $View -BlueCatSession $BlueCatSession -ErrorAction SilentlyContinue
        }

        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to a Zone Record"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Name '$($Name)' in View '$($View.name)' to a Zone Record"
            }
            throw $FailureMessage
            Write-Verbose $FailureMessage
            return
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid Zone Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'Zone') {
            $FailureMessage = "$($thisFN): Not a Zone record - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteZone = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting Zone record for '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteZone
    }
}
