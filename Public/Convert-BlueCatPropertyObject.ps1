function Convert-BlueCatPropertyObject {
    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,Position=0)]
        [psobject] $PropertyObject
    )

    process {
        $PropertyString=''
        foreach ($item in $PropertyObject.PSObject.Properties) {
            if ($item.Name -notmatch '^ip4[bn].*') {
                $PropertyString += "$($item.Name)=$($item.Value)|"
            }
        }

        if ($PropertyString.Length -gt 0) {
            $PropertyString
        }
    }
}
