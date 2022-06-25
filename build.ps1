param(
    $version=$null
)
$module = 'PSBicepApiManagement'
Push-Location $PSScriptRoot


if(Test-Path './output'){
    Remove-Item './output' -Force -Recurse
}
mkdir "$PSScriptRoot/output"
mkdir "$PSScriptRoot/output/$module"
mkdir "$PSScriptRoot/output/$module/scripts"

Copy-item "$PSScriptRoot/src/*" "$PSScriptRoot/output/$module/scripts/"
Copy-Item "$PSScriptRoot/$module/*" "$PSScriptRoot/output/$module" -Recurse -Force

if($null -ne $version)
{
    Update-ModuleManifest -Path "$PSScriptRoot\output\$module\$module.psd1" -ModuleVersion $version
}
Pop-Location

