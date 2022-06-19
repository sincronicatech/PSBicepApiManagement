$module = 'PSBicepApiManagement'
Push-Location $PSScriptRoot


if(Test-Path './output'){
    Remove-Item './output' -Force -Recurse
}
mkdir "$PSScriptRoot/output/$module/scripts"

Copy-item "$PSScriptRoot/src/*" "$PSScriptRoot/output/$module/scripts/"
Copy-Item "$PSScriptRoot/$module/*" "$PSScriptRoot/output/$module" -Recurse -Force

#Import-Module "$PSScriptRoot/output/$module/$module.psd1"
#Invoke-Pester "$PSScriptRoot\tests"
Pop-Location