function Convert-BlueCatPropertyString {
<#
.SYNOPSIS
    Converts a property string to a PSCustomObject
.DESCRIPTION
    The Convert-BlueCatPropertyString cmdlet converts a pipe (|) delimited name=value pair string from the BlueCat API into a PSCustomObject so that properties can be referenced as object members by name.
.PARAMETER Property
    A string value representing object properties as returned by the BlueCat API
.EXAMPLE
    PS> $PropertyObject = Convert-BlueCatPropertyString -Property $PropertyString
.EXAMPLE
    PS> $PropertyObject = $PropertyString | Convert-BlueCatPropertyString
.INPUTS
    [string] value as returned by the BlueCat API, '|' delimited name=value pairs
.OUTPUTS
    [PSCustomObject]
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [Alias('Properties','PropertyString')]
        [string] $Property
    )

    process {
        $PropertyObject = New-Object -TypeName psobject
        $Properties     = $Property.TrimEnd('|').Split('|')
        foreach ($PropertyItem in $Properties) {
            $bits = $PropertyItem.Split('=',2)
            $PropertyObject | Add-Member -MemberType NoteProperty -Name $bits[0] -Value $bits[1]
        }

        $PropertyObject
    }
}
