function Convert-BlueCatPropertyString {
    [cmdletbinding()]
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
