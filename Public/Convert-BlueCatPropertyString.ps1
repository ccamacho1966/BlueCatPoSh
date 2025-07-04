function Convert-BlueCatPropertyString {
    [cmdletbinding()]
    param(
        [parameter(Mandatory,ValueFromPipeline,Position=0)]
        [string] $PropertyString
    )

    process {
        $newObj = New-Object -TypeName psobject
        $prop = $PropertyString.TrimEnd('|').Split('|')
        foreach ($item in $prop) {
            $bits = $item.Split('=',2)
            $newObj | Add-Member -MemberType NoteProperty -Name $bits[0] -Value $bits[1]
        }

        $newObj
    }
}
