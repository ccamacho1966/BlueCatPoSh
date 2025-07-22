function Convert-BlueCatPropertyObject {
<#
.SYNOPSIS
    Converts a property object to a BlueCat property string
.DESCRIPTION
    The Convert-BlueCatPropertyObject cmdlet converts a property object to a BlueCat property string.
    
    This returns a pipe (|) delimited name=value pair string that the BlueCat API requires when setting an object's properties.
.PARAMETER Property
    A PSCustomObject representing object properties to be used by the BlueCat API
.EXAMPLE
    PS> $PropertyString = Convert-BlueCatPropertyObject -Property $PropertyObject
.EXAMPLE
    PS> $PropertyString = $PropertyObject | Convert-BlueCatPropertyObject
.INPUTS
    [PSCustomObject]
.OUTPUTS
    [string] Pipe (|) delimited name=value pair string that the BlueCat API requires when setting an object's properties
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [Alias('Properties','PropertyObject')]
        [PSCustomObject] $Property
    )

    process {
        $PropertyString=''
        foreach ($item in $Property.PSObject.Properties) {
            if ($item.Name -notmatch '^ip4[bn].*') {
                if ((($item.Value).GetType()).Name -eq 'Boolean') {
                    $PropertyString += "$($item.Name)=$(($item.Value).toString().toLower())|"
                } else {
                    $PropertyString += "$($item.Name)=$($item.Value)|"
                }
            }
        }

        if ($PropertyString.Length -gt 0) {
            $PropertyString
        }
    }
}
