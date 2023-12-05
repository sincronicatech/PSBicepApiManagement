function Export-PSBicepApiManagementService (
    $SubscriptionId ,
    $ResourceGroupName ,
    $ApiManagementName 
)
{
    write-host "Connecting to Subscription Id $SubscriptionId"
    get-azcontext -ListAvailable|Where-Object{$_.Subscription.Id -eq $SubscriptionId}|select-azcontext|out-null
    $sourceApiManagement= Get-AzApiManagement -Name $ApiManagementName -ResourceGroupName $ResourceGroupName

    $tempFile = Join-Path $env:TEMP "$(get-random).json"
    $tempBicepConfigPath = Join-Path $env:TEMP "bicepconfig.json"

    write-host "Exporting Api Management to $tempFile"
    $exportFile = Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Resource $sourceApiManagement.Id -Path "$tempFile" -IncludeParameterDefaultValue
    Copy-Item (Join-path $PSScriptRoot "bicepconfig.json") $tempBicepConfigPath
    bicep decompile $exportFile.Path --outfile "$($exportFile.Path).bicep"|Out-Null
    $bicepData = Get-Content "$($exportFile.Path).bicep" -Raw   

    Remove-Item "$tempFile"
    write-host "  $tempFile removed"
    Remove-Item "$($exportFile.Path).bicep"
    write-host "  $($exportFile.Path).bicep removed"
    Remove-Item   $tempBicepConfigPath

    $bicepDocument = $bicepData|ConvertFrom-PSBicepDocument 
    
    return $bicepDocument
}