function Get-BlueCatConfig {
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline,Position=0)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    process {
        if ($BlueCatSession.idConfig) {
            $objConf = New-Object -TypeName psobject
            $objConf | Add-Member -MemberType NoteProperty -Name id -Value $BlueCatSession.idConfig
            $objConf | Add-Member -MemberType NoteProperty -Name type -Value 'Configuration'
            $objConf | Add-Member -MemberType NoteProperty -Name name -Value $BlueCatSession.Config

            $objConf
        }
    }
}
