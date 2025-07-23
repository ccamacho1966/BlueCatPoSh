function Get-BlueCatEntities {
<#
.SYNOPSIS
    Retrieve BlueCat Entities (API Call: getEntities)
.DESCRIPTION
    The Get-BlueCatEntities cmdlet allows the retrieval of BlueCat entities by type.

    This call is useful for retrieving lists of entities. More specific calls exist to retrieve specific records.

    ParentID is silently ignored (set to 0) when searching for Configurations.
.PARAMETER ParentID
    An integer value that represents the entity ID of the parent to be searched.

    This should be set to 0 for Configurations, but is silently overridden when searching for Configurations.
.PARAMETER EntityType
    A string value representing the entity type to search for.
.PARAMETER Start
    An integer value defining the index to start returning results from. The default start value is 0.
.PARAMETER Count
    An integer value defining how many results to return for each query. The default count value is 10.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatEntities -ParentID 105127 -EntityType 'AliasRecord'

    Returns one or more PSCustomObjects representing Alias Records under the supplied parent ID, which should be a zone in this case.
    A null value is returned if the search finds no objects of the requested type.
    BlueCatSession will default to the current default session.
    Start will default to 0. Count will default to 10.
.EXAMPLE
    PS> Get-BlueCatEntities -ParentID 105272 -EntityType 'HostRecord' -Start 100 -Count 100 -BlueCatSession $Session3

    Returns one or more PSCustomObjects representing Host Records under the supplied parent ID, which should be a zone in this case.
    A null value is returned if the search finds no objects of the requested type (or there are less than 100 objects in total).
    BlueCatSession $Session3 will be used for this search.
    Since Start is set to 100, the first 100 objects (index 0-99) will be skipped.
    Since Count is set to 100, objects 100-199 will be returned.
.INPUTS
    None
.OUTPUTS
    One or more PSCustomObjects representing BlueCat entities.
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $ParentID,

        [Parameter(Mandatory)]
        [string] $EntityType,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Start = 0,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int] $Count = 10,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        Write-Verbose "$($thisFN): EntityType='$($EntityType)', ParentID='$($ParentID)', Start=$($Start), Count=$($Count)"

        if ($EntityType -eq 'Configuration') {
            $Query = "getEntities?parentId=0"
        } else {
            $Query = "getEntities?parentId=$($ParentID)"
        }

        $Query += "&type=$($EntityType)&start=$($Start)&count=$($Count)"
        [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        Write-Verbose "$($thisFN): Retrieved $($BlueCatReply.Count) records"

        if ($BlueCatReply) {
            $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
