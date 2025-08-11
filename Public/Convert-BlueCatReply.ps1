function Convert-BlueCatReply {
<#
.SYNOPSIS
    Convert BlueCat API responses to standard objects.
.DESCRIPTION
    Convert-BlueCatReply is a macro-function that converts a variety of BlueCat API responses to standard object formats.

    In addition to simple conversion, this cmdlet will gather additional related information and add it to the object to improve the usability of the gathered information and ideally reduce the need for additional API calls to gather commonly used related information.
.PARAMETER RawObject
    A PSCustomObject representing the 'raw' reply received from the BlueCat API.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for related lookups.
.EXAMPLE
    PS> $BlueCatObject = Convert-BlueCatReply -RawObject $BlueCatReply

    Converts the raw reply $BlueCatReply to a standard rich object and saves the result as $BlueCatObject
    Use the default BlueCat session for any additional lookups
.EXAMPLE
    PS> $BlueCatObject = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $Session8

    Converts the raw reply received on the pipeline to a standard rich object and saves the result as $BlueCatObject
    Use the BlueCat session associated with $Session8 for any additional lookups
.INPUTS
    [PSCustomObject] representing the raw reply received from the BlueCat API
.OUTPUTS
    [PSCustomObject] with standardized formatting and enriched information
#>
    [CmdletBinding()]

    param(
        [Parameter(ValueFromPipeline,Mandatory)]
        [PSCustomObject] $RawObject,

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

        # Check for id=0 which indicates no actual BlueCat entity in the object
        if (-not $RawObject.id) {
            # Not a valid object. Issue a warning and return the raw object as-is.
            Write-Warning "$($thisFN): Invalid BlueCat object passed - returning object as-is"
            return $RawObject
        }

        Write-Verbose "$($thisFN): $($RawObject | ConvertTo-Json -Depth 5 -Compress)"

        # All BlueCat objects have an ID, name, and object type
        $newObj = New-Object -TypeName PSCustomObject
        $newObj | Add-Member -MemberType NoteProperty -Name 'id'   -Value $RawObject.id
        $newObj | Add-Member -MemberType NoteProperty -Name 'name' -Value $RawObject.name
        $newObj | Add-Member -MemberType NoteProperty -Name 'type' -Value $RawObject.type

        # Create a custom sub-object from the BlueCat properties string
        if ($RawObject.properties) {
            $newPropObj = $RawObject.properties | Convert-BlueCatPropertyString
            if ($newPropObj.addresses) {
                $addrObj = ($newPropObj.addresses -split ',' | Where-Object -FilterScript { $_ })
                $newPropObj | Add-Member -MemberType NoteProperty -Name 'address' -Value $addrObj
            }
            if ($RawObject.type -match '^IP4[BN].*') {
                # Create a 'specs' object member for IP4 Blocks and Networks
                if ($newPropObj.CIDR) {
                    $specs = [PSCustomObject]@{'type'='CIDR'; 'spec'=$($newPropObj.CIDR)}
                } else {
                    $specs = [PSCustomObject]@{'type'='Range'; 'spec'="$($newPropObj.start)-$($newPropObj.end)"}
                }
                $newPropObj | Add-Member -MemberType NoteProperty -Name ($RawObject.type.toLower()) -Value $specs
            }
            # Add both the original BlueCat string and the newly created object to the custom object
            $newObj | Add-Member -MemberType NoteProperty -Name 'property'   -Value $newPropObj
            $newObj | Add-Member -MemberType NoteProperty -Name 'properties' -Value $RawObject.properties
        }

        if ($RawObject.type -eq 'View') {
            # Add a Config reference to views and that is all
            $configObj = Get-BlueCatParent -Connection $BlueCatSession -id $RawObject.id
            $newObj    | Add-Member -MemberType NoteProperty -Name 'config' -Value $configObj
        } elseif ($RawObject.type -notin ('Configuration','NetworkInterface','NetworkServerInterface','PublishedServerInterface')) {
            # Configurations and Server Interfaces do not get config or view references

            # Create a 'shortName' for DNS records - Replace the default name with the absolute name
            if (($newObj.type -eq 'Zone') -or ($newObj.type -match '.*Record$')) {
                if ($newObj.type -ne 'ExternalHostRecord') {
                    # External Host Records do not have short names
                    $newObj | Add-Member -MemberType NoteProperty -Name 'shortName' -Value $newObj.name
                }
                if ($newObj.property.absoluteName) { $newObj.name = $newObj.property.absoluteName }
            }

            # Conditionally add config and view references to objects
            if (($newObj.type -eq 'Server') -or ($newObj.type -match '^IP4[BNA].*')) {
                # Only include config reference
                $configObj = Trace-BlueCatRoot -Object $newObj -Type Configuration -BlueCatSession $BlueCatSession
            } else {
                # Include both a config and view reference
                $viewObj   = Trace-BlueCatRoot -Object $newObj -Type View -BlueCatSession $BlueCatSession
                $configObj = $viewObj.config
            }

            if ($newObj.type -eq 'MXRecord') {
                # Directly expose MX properties
                $newObj | Add-Member -MemberType NoteProperty -Name relay      -Value $newObj.property.linkedRecordName
                $newObj | Add-Member -MemberType NoteProperty -Name priority   -Value $newObj.property.priority
            } elseif ($newObj.type -eq 'SRVRecord') {
                # Directly expose SRV properties
                $newObj | Add-Member -MemberType NoteProperty -Name target     -Value $newObj.property.linkedRecordName
                $newObj | Add-Member -MemberType NoteProperty -Name port       -Value $newObj.property.port
                $newObj | Add-Member -MemberType NoteProperty -Name priority   -Value $newObj.property.priority
                $newObj | Add-Member -MemberType NoteProperty -Name weight     -Value $newObj.property.weight
            } elseif ($newObj.type -eq 'TXTRecord') {
                $newObj | Add-Member -MemberType NoteProperty -Name text       -Value $newObj.property.txt
            } elseif ($newObj.type -eq 'Zone') {
                # Directly expose Zone deployable flag
                $newObj | Add-Member -MemberType NoteProperty -Name deployable -Value $newObj.property.deployable
            } elseif ($newObj.type -eq 'AliasRecord') {
                # Directly expose alias target
                $newObj | Add-Member -MemberType NoteProperty -Name target     -Value $newObj.property.linkedRecordName
            }

            if ($viewObj)   { $newObj | Add-Member -MemberType NoteProperty -Name view   -Value $($viewObj)   }
            if ($configObj) { $newObj | Add-Member -MemberType NoteProperty -Name config -Value $($configObj) }
        }

        # Return the converted reply
        $newObj
    }
}
