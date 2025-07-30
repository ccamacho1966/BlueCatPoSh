Function Get-BlueCatServer {
<#
.SYNOPSIS
    Retrieve a BlueCat Server definition
.DESCRIPTION
    The Get-BlueCatServer cmdlet retrieves the definition of a server defined in BlueCat.
.PARAMETER Name
    A string value representing the name of the server definition to be retrieved.

    If not specified, all servers will be retrieved for the specified configuration.
.PARAMETER ConfigID
    An integer value representing the entity ID of the desired configuration.
.PARAMETER Config
    A PSCustomObject representing the desired configuration.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatServer -Name dns1.example.com

    Returns a PSCustomObject representing the requested server, or NULL if not found.
    BlueCatSession will default to the current default session.
    Configuration will default to the BlueCatSession default configuration.
.EXAMPLE
    PS> Get-BlueCatServer -Name dhcp9.example.com -ConfigID 1354 -BlueCatSession $Session2

    Returns a PSCustomObject representing the requested server, or NULL if not found.
    Use the BlueCatSession associated with $Session2 to perform this lookup.
    The record will be searched for in configuration 1354.
.EXAMPLE
    PS> Get-BlueCatServer -ConfigID 1323

    Returns one or more PSCustomObjects representing all server definitions in configuration 1323, or NULL if none are found.
    BlueCatSession will default to the current default session.
.INPUTS
    None
.OUTPUTS
    One or more PSCustomObjects representing server definitions, or NULL if not found.

    [int] id
    [string] name
    [string] type = 'Server'
    [string] properties
    [PSCustomObject] property
    [PSCustomObject[]] published
    [PSCustomObject[]] interface
    [PSCustomObject] config
    [PSCustomObject] zone
#>
    [CmdletBinding(DefaultParameterSetName='byID')]

    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Server','HostName')]
        [string] $Name,

        [Parameter(ParameterSetName='byID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ConfigID,

        [Parameter(ParameterSetName='byObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Config,

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

        if ($Config.ID) {
            # Use the Config ID supplied with the object
            $ConfigID = $Config.ID
        }
        if (-not $ConfigID) {
            # No Config ID or Object was supplied so try to use the session default
            $BlueCatSession | Confirm-Settings -Config
            $ConfigID = $BlueCatSession.Config.id
        }

        $LookupParms = @{
            EntityType     = 'Server'
            ParentID       = $ConfigID
            BlueCatSession = $BlueCatSession
        }
        if ($Name) {
            # Retrieve a specific named server
            $LookupParms.Name = $Name
            $ServerList = [PSCustomObject[]] (Get-BlueCatEntityByName @LookupParms)
        } else {
            # Retrieve all servers in the specified or default config
            $ServerList = [PSCustomObject[]] (Get-BlueCatEntities @LookupParms)
        }

        foreach ($ServerObj in $ServerList) {
            Write-Verbose "$($thisFN): Selected #$($ServerObj.id) as '$($ServerObj.name)'"

            # Pull a list of published interfaces for this server
            $BlueCatReply = [PSCustomObject[]] (Get-BlueCatEntities -ParentID $ServerObj.id -EntityType 'PublishedServerInterface' -BlueCatSession $BlueCatSession)

            if (-not $BlueCatReply.Count) {
                # This server has no published interfaces
                Write-Verbose "$($thisFN): No published interfaces found for '$($ServerObj.name)'"
                $Published = $null
            } else {
                $Published = @()
                foreach ($RawEntry in $BlueCatReply) {
                    $PubEntry = $RawEntry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                    Write-Verbose "$($thisFN): Published Interface #$($PubEntry.id) as '$($PubEntry.name)' for '$($ServerObj.name)'"
                    $Published += $PubEntry
                }
            }
            $ServerObj | Add-Member -MemberType NoteProperty -Name published -Value $Published

            # Pull a list of network interfaces for this server
            $BlueCatReply = [PSCustomObject[]] (Get-BlueCatEntities -ParentID $ServerObj.id -EntityType 'NetworkServerInterface' -BlueCatSession $BlueCatSession)

            if (-not $BlueCatReply.Count) {
                # This server has no interfaces
                Write-Verbose "$($thisFN): No network interfaces found for '$($ServerObj.name)'"
                $Interfaces = $null
            } else {
                $Interfaces = @()
                foreach ($RawEntry in $BlueCatReply) {
                    $IntfEntry = $RawEntry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                    Write-Verbose "$($thisFN): Found Interface #$($IntfEntry.id) as '$($IntfEntry.name)' for '$($ServerObj.name)'"
                    $Interfaces += $IntfEntry
                }
            }
            $ServerObj | Add-Member -MemberType NoteProperty -Name interface -Value $Interfaces

            $ServerObj
        }
    }
}
