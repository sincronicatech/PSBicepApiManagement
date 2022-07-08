<#
    .Synopsis
        Export an entire Api version set from an Api Management instance as Bicep file

    .Description
        Generates a Bicep file of a Api Version set. It includes all child objects and referes external objects as existing
        resources in the Bicep file.

    .Parameter SubcriptionId
        Subcription id containing the source Api Management instance

    .Parameter ResourceGroupName
        Name of the resource group containing the source Api Management instance

    .Parameter ApiManagementName
        Name of the source Api Management instance

    .Parameter ApiVersionSetId
        VersionSet Id of the Apis to export.
    
    .Parameter TargetFile
        Path of the target Bicep file
        
    .Example
        # Exports an Api
        Export-PSBicepApiManagementApiVersionSet -SubscriptionId '00000000-1111-2222-3333-444444444444' -ResourceGroupName 'Api-management-CICD' -ApiManagementName 'Api-management-src' -ApiVersionSetId '62a8b0a2ccab053b96e10e3f' -TargetFile .\ApiVSExport.bicep

#>
function Export-PSBicepApiManagementApiVersionSet (
    $SubscriptionId ,
    $ResourceGroupName ,
    $ApiManagementName ,
    $ApiVersionSetId ,
    $TargetFile
)
{
    $ErrorActionPreference= 'Stop'

    $bicepDocument = Export-PSBicepApiManagementService -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -ApiManagementName $ApiManagementName
    $sourceApiManagement= $bicepDocument.Resources|Where-Object{$_.ResourceType.StartsWith('''Microsoft.ApiManagement/service@')}

    $ResourcesToBeAnalyzed = @()
    $ResourcesAnalyzed = @()

    write-host "Searching Api Version Set $ApiVersionSetId"
    $ApiVersionSetResource = $bicepDocument.Resources|Where-Object{$_.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apiVersionSets@') -and $_.Name -eq "'$ApiVersionSetId'"}
    $ResourcesToBeAnalyzed += $ApiVersionSetResource

    $ApiResources = $bicepDocument.Resources|Where-Object { $null -ne $_.Attributes.properties.apiVersionSetId -and  $_.Attributes.properties.apiVersionSetId.Split('.')[0] -eq $ApiVersionSetResource.identifier}
    $ResourcesToBeAnalyzed += $ApiResources

    Write-PSBicepApiManagementExportedResources -bicepDocument $bicepDocument -sourceApiManagement $sourceApiManagement -ResourcesToBeAnalyzed $ResourcesToBeAnalyzed -ResourcesAnalyzed $ResourcesAnalyzed -TargetFile $TargetFile

}