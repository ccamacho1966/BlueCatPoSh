function Trace-BlueCatRoot {
<#
.SYNOPSIS
    Determine the configuration and/or view associated with a BlueCat entity.
.DESCRIPTION
    The Trace-BlueCatRoot cmdlet is a utility function that traces an entity through the BlueCat hierarchy to determine the associated configuration and/or view.

    When a View is traced, the information will include the Configuration in the returned object.
.PARAMETER ID
    An integer value representing the entity ID of the entity to be traced.
.PARAMETER Object
    A PSCustomObject representing the entity to be traced.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for related lookups.
.EXAMPLE
    PS> $BlueCatView   = Trace-BlueCatRoot -Object $BlueCatEntity -Type View
    PS> $BlueCatConfig = $BlueCatView.config

    Traces the entity's hierarchy until the view is found.
    The returned view object will contain a link to the configuration.
    Use the default BlueCat session for any additional lookups
.EXAMPLE
    PS> $BlueCatConfig = Trace-BlueCatRoot -Object $BlueCatEntity

    Traces the entity's hierarchy until the configuration is found.
    If not specified, the default type traced will be the configuration.
    Use the default BlueCat session for any additional lookups
.INPUTS
    [PSCustomObject] representing the entity to be traced
.OUTPUTS
    [PSCustomObject] representing the view and/or configuration
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

        [Parameter()]
        [ValidateSet('Configuration','View')]
        [string] $Type='Configuration',

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

        if ($Object) {
            if (-not $Object.id) {
                throw "$($thisFN): Invalid object - Does not contain an Entity ID"
            }
            $ID = $Object.id
            Write-Verbose "$($thisFN): Trace $($Type) for $($Object.type) $($Object.name)"
        } else {
            Write-Verbose "$($thisFN): Trace $($Type) for Entity ID:$($ID)"
        }

        do {
            $Query = "getParent?entityId=$($ID)"
            $parent = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
            if (-not $parent.id) {
                throw "Parent for Entity Id $($ID) not found!"
            }
            if ($parent.type -ne $Type) {
                $ID = $parent.id
            }
        } while ($parent.type -ne $Type)
        
        $newObj = New-Object -TypeName PSCustomObject
        $newObj | Add-Member -MemberType NoteProperty -Name 'id'   -Value $parent.id
        $newObj | Add-Member -MemberType NoteProperty -Name 'name' -Value $parent.name
        $newObj | Add-Member -MemberType NoteProperty -Name 'type' -Value $parent.type
        Write-Verbose "$($thisFN): Found $($Type) $($newObj | ConvertTo-Json -Depth 9 -Compress)"

        if ($parent.type -eq 'View') {
            # Add the Configuration to a View object
            $newObj | Add-Member -MemberType NoteProperty -Name 'config' -Value (Get-BlueCatParent -id ($parent.id) -BlueCatSession $BlueCatSession)
        }

        $newObj
    }
}
