function Convert-BlueCatPropertyObject {
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
                $PropertyString += "$($item.Name)=$($item.Value)|"
            }
        }

        if ($PropertyString.Length -gt 0) {
            $PropertyString
        }
    }
}
