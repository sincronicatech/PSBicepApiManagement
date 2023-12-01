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


Copy-item "$PSScriptRoot/src/$module/*" "$PSScriptRoot/output/$module"
Copy-item "$PSScriptRoot/src/$module/scripts/*" "$PSScriptRoot/output/$module/scripts"

if($null -ne $version)
{
    
    #import required modules to update the manifest
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Import-LocalizedData -BaseDirectory "$PSScriptRoot\output\$module" -FileName "$module.psd1" -BindingVariable manifest
    foreach($moduleName in $manifest.RequiredModules){
        if($moduleName -is [hashtable]){
            $requiredModuleName = $moduleName.ModuleName
            $requiredModuleVersion = $moduleName.Version
            Install-Module -Name $requiredModuleName -RequiredVersion $requiredModuleVersion -Force -Confirm:$false
        }
        else{
            Install-Module -Name $moduleName -Force -Confirm:$false
        }
    }
    #Finally update the manifest
    Update-ModuleManifest -Path "$PSScriptRoot\output\$module\$module.psd1" -ModuleVersion $version
}
if($null -eq (Get-Module -ListAvailable Microsoft.PowerShell.Archive)){
    install-module Microsoft.PowerShell.Archive -Force -Confirm:$false
}
import-module Microsoft.PowerShell.Archive

Compress-Archive "./output/$module/" "./output/$module.zip"
Pop-Location

