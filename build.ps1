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
    
    #import required modules to update the manifest
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Import-LocalizedData -BaseDirectory "$PSScriptRoot\output\$module" -FileName "$module.psd1" -BindingVariable manifest
    foreach($moduleName in $manifest.RequiredModules){
        Install-Module -Name $moduleName -Force -Confirm:$false
    }
    #Finally update the manifest
    Update-ModuleManifest -Path "$PSScriptRoot\output\$module\$module.psd1" -ModuleVersion $version
}
./Compress-Archive "./output/$module/" "./output/$module.zip"
Pop-Location

