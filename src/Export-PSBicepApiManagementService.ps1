function Export-PSBicepApiManagementService (
    $SubscriptionId ,
    $ResourceGroupName ,
    $ApiManagementName 
)
{
    write-host "Connecting to Subscription Id $SubscriptionId"
    Set-AzContext -SubscriptionId $SubscriptionId|Out-Null
    $sourceApiManagement= Get-AzApiManagement -Name $ApiManagementName -ResourceGroupName $ResourceGroupName

    $tempFile = "$($env:TEMP)/$(get-random).json"
    write-host "Exporting Api Management to $tempFile"
    $exportFile = Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Resource $sourceApiManagement.Id -Path "$tempFile" -IncludeParameterDefaultValue
    Copy-Item "$PSScriptRoot/bicepconfig.json" "$($env:TEMP)/bicepconfig.json"
    bicep decompile $exportFile.Path --outfile "$($exportFile.Path).bicep"|Out-Null
    $bicepData = Get-Content "$($exportFile.Path).bicep" -Raw   

    Remove-Item "$tempFile"
    write-host "  $tempFile removed"
    Remove-Item "$($exportFile.Path).bicep"
    write-host "  $($exportFile.Path).bicep removed"
    Remove-Item "$($env:TEMP)/bicepconfig.json"

    $bicepDocument = $bicepData|ConvertFrom-PSBicepDocument 

    $sourceApiManagement= $bicepDocument.Resources|Where-Object{$_.ResourceType.StartsWith('''Microsoft.ApiManagement/service@')}
    return $sourceApiManagement
}