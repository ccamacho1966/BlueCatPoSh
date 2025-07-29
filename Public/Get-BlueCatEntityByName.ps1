function Get-BlueCatEntityByName {
<#
.SYNOPSIS
    Retrieve BlueCat Entity by its name (API Call: getEntityByName)
.DESCRIPTION
    The Get-BlueCatEntityByName cmdlet allows the retrieval of a specific BlueCat entity by its name. An Entity Type and parent Entity ID is required to do the lookup.

    In the event there is more than one match, only a single record is returned by the API.
.PARAMETER Name
    A string value representing the short name of the entity to be retrieved.

    To lookup DNS entities that match the zone name, set name to '', '.', '@', or NULL.
.PARAMETER EntityType
    A string value representing the entity type to search for.
.PARAMETER ParentID
    An integer value that represents the entity ID of object to be retrieved.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatEntityByName -Name '' -EntityType 'MXRecord' -ParentID 104399

    Returns a PSCustomObject representing the MX record linked to the parent zone name.
    A null value is returned if the Entity does not exist.
    Only a single value is returned if multiple Entity matches exist.
    The search is performed in the zone represented by Entity ID 104399.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> Get-BlueCatEntityByName -Name 'www' -EntityType 'AliasRecord' -ParentID 103949 -BlueCatSession $Session7

    Returns a PSCustomObject representing the CNAME record linked to 'www' under the parent zone.
    A null value is returned if the Entity does not exist.
    The search is performed in the zone represented by Entity ID 103949.
    BlueCatSession $Session7 will be used to conduct the search.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing BlueCat entity, or NULL if not found.
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [Alias('EntityName')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntityType,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $ParentID,

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

        if ($Name -in ('','.','@')) {
            $Name = $null
        }

        $verboseOutput = "$($thisFN): Name='$($Name)', EntityType='$($EntityType)'"
        if ($ParentID) { $verboseOutput += ", ParentID='$($ParentID)'" }
        Write-Verbose $verboseOutput

        if ($EntityType -eq 'Configuration') {
            $Query = "getEntityByName?parentId=0"
        } else {
            if (-not $ParentID) {
                $BlueCatSession | Confirm-Settings -Config
                $ParentID = $BlueCatSession.Config.id
            }
            $Query = "getEntityByName?parentId=$($ParentID)"
        }

        $Query += "&name=$($Name)&type=$($EntityType)"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
        if (-not $BlueCatReply.id) {
            throw "$($EntityType) $($Name) not found: $($BlueCatReply)"
        }
        Write-Verbose "$($thisFN): Selected $($BlueCatReply.type) #$($BlueCatReply.id) as $($BlueCatReply.name)"

        $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
    }
}
