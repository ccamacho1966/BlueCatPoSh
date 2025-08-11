function Remove-BlueCatAlias {
<#
.SYNOPSIS
    Remove an Alias (CNAME)
.DESCRIPTION
    The Remove-BlueCatAlias cmdlet allows the removal of DNS CNAME records.

    A Canonical Name (CNAME) record is a type of resource record in the Domain Name System (DNS) that maps one domain name (an alias) to another (the canonical name).
.PARAMETER Name
    A string value representing the FQDN of the CNAME (Alias) to be removed.
.PARAMETER ID
    An integer value representing the entity ID of the alias to be removed.
.PARAMETER Object
    A PSCustomObject representing the alias to be removed.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object operation.
.EXAMPLE
    PS> Remove-BlueCatAlias -Name myalias.example.com

    Removes the alias 'myalias.example.com' or throws an error if the alias is not found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Remove-BlueCatAlias -Name myservice.example.com -ViewID 23456 -BlueCatSession $Session6

    Removes the alias 'myservice.example.com' or throws an error if the alias is not found.
    Use the BlueCatSession associated with $Session6 to perform this operation.
    The record will be searched for in view 23456.
.EXAMPLE
    PS> Remove-BlueCatAlias -ID 10102

    Removes the alias with entity ID 10102 or throws an error if the alias is not found.
    BlueCatSession will default to the current default session.
    View will be automatically selected based on the entity ID.
.EXAMPLE
    PS> $AliasObject | Remove-BlueCatAlias

    Removes the alias represented by $AliasObject which is passed on the pipeline.
    BlueCatSession will default to the current default session.
    View will be automatically selected based on the entity information.
.INPUTS
    PSCustomObject representing the alias to be removed.
.OUTPUTS
    None
#>
    [CmdletBinding(DefaultParameterSetName='byID')]

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
        [Alias('AliasName')]
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

            $Object = Get-BlueCatAlias -Name $Name -View $View -BlueCatSession $BlueCatSession
        }

        if (-not $Object) {
            if ($ID) {
                $FailureMessage = "$($thisFN): Failed to convert Entity ID #$($ID) to an Alias Record"
            } else {
                $FailureMessage = "$($thisFN): Failed to convert Name '$($Name)' in View '$($View.name)' to an Alias Record"
            }
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if (-not $Object.ID) {
            $FailureMessage = "$($thisFN): Invalid Alias Object"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        if ($Object.type -ne 'AliasRecord') {
            $FailureMessage = "$($thisFN): Not an Alias Record - $($Object.Name) is type '$($Object.type)'"
            Write-Verbose $FailureMessage
            throw $FailureMessage
        }

        $DeleteAlias = @{
            ID             = $Object.ID
            BlueCatSession = $BlueCatSession
        }

        Write-Verbose "$($thisFN): Deleting alias record for '$($Object.Name)' (ID:$($Object.ID))"
        Remove-BlueCatEntityById @DeleteAlias
    }
}
