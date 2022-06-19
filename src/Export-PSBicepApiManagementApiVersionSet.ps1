
function Export-PSBicepApiManagementApiVersionSet (
    $SubscriptionId ,
    $ResourceGroupName ,
    $ApiManagementName ,
    $ApiVersionSetId ,
    $TargetFile
)
{
    $ErrorActionPreference= 'Stop'

    write-host "Connecting to Subscription Id $SubscriptionId"
    Set-AzContext -SubscriptionId $SubscriptionId|Out-Null
    $sourceApiManagement= Get-AzApiManagement -Name $ApiManagementName -ResourceGroupName $ResourceGroupName

    $tempFile = "$($env:TEMP)\$(get-random).json"
    write-host "Exporting API Management to $tempFile"
    $exportFile = Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Resource $sourceApiManagement.Id -Path "$tempFile" -IncludeParameterDefaultValue
    bicep decompile $exportFile.Path --outfile "$($exportFile.Path).bicep"|Out-Null
    $bicepData = Get-Content "$($exportFile.Path).bicep" -Raw   

    Remove-Item "$tempFile"
    write-host "  $tempFile removed"
    Remove-Item "$($exportFile.Path).bicep"
    write-host "  $($exportFile.Path).bicep removed"

    $bicepDocument = $bicepData|ConvertFrom-PSBicepDocument 

    $sourceApiManagement= $bicepDocument.Resources|Where-Object{$_.ResourceType.StartsWith('''Microsoft.ApiManagement/service@')}

    $ResourcesToBeAnalyzed = @()
    $ResourcesAnalyzed = @()

    write-host "Searching API Version Set $ApiVersionSetId"
    $apiVersionSetResource = $bicepDocument.Resources|Where-Object{$_.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apiVersionSets@') -and $_.Name -eq "'$ApiVersionSetId'"}
    $ResourcesToBeAnalyzed += $apiVersionSetResource

    $apiResources = $bicepDocument.Resources|Where-Object { $null -ne $_.Attributes.properties.apiVersionSetId -and  $_.Attributes.properties.apiVersionSetId.Split('.')[0] -eq $apiVersionSetResource.identifier}
    $ResourcesToBeAnalyzed += $apiResources


    write-host "Searching child resources to be exported"

    $resourceCounter = 0
    while($resourceCounter -lt $ResourcesToBeAnalyzed.Length){ #since there is no native Stack object on Powershell (other than using the .net version), the script will use an array and an incremental index to analyze all data inside the array
        $ResourceToAnalyze = $ResourcesToBeAnalyzed[$resourceCounter];
        $ResourcesToBeAnalyzed += $bicepDocument.Resources|Where-Object{$_.Parent -eq $ResourceToAnalyze.Identifier}
        $ResourcesAnalyzed+=$ResourceToAnalyze;
        $resourceCounter+=1
    }

    write-host "Searching outer dependencies"
    #These objects will not be exported, but will be referred as existing in the outer script

    $exportedIdentifiers = $ResourcesAnalyzed.Identifier
    $AllReferredIdentifiers=@()
    foreach($resourceAnalyzed in $resourcesAnalyzed){
        $AllReferredIdentifiers += Get-PSBicepReference -ElementObject $resourceAnalyzed
    }


    $AllReferredIdentifiers=$AllReferredIdentifiers|Select-Object -unique
    $referenceCounter = 0;

    while($referenceCounter -lt $AllReferredIdentifiers.Count){
        $id = $AllReferredIdentifiers[$referenceCounter]
        $referenceCounter+=1
        
        if($exportedIdentifiers -contains $id)
        {
            continue;
        }
        $ReferredOuterResource = Resolve-PSBicepReference -Identifier $id -Document $bicepDocument
        $ResourceToAdd=$null
        if($ReferredOuterResource.ElementType -eq "Resource")
        {
            $ResourceToAdd= New-PSBicepResource -Identifier $id -ResourceType $ReferredOuterResource.ResourceType -IsExisting:$true -Name $ReferredOuterResource.Name
        }
        else{
            if($ReferredOuterResource.ElementType -eq 'Param' -and $ReferredOuterResource.Identifier -eq $sourceApiManagement.Name){
                $ReferredOuterResource.DefaultValue='''#TargetApiManagement#'''
            }
            $ResourceToAdd=$ReferredOuterResource;
        }
        $ResourcesAnalyzed+=$ResourceToAdd;
        $ReferredIdentifiers = Get-PSBicepReference -ElementObject $ResourceToAdd
        foreach($referredIdentifier in $ReferredIdentifiers)
        {
            if(-not($AllReferredIdentifiers -contains $referredIdentifier))
            {
                $AllReferredIdentifiers+=$referredIdentifier;
            }
        }
    }

    write-host "Writing new bicep document $TargetFile.bicep"
    $newDocument = New-PSBicepDocument
    foreach($obj in $resourcesAnalyzed){
        $newDocument.Add($obj)
    }

    $newDocument|ConvertTo-PSBicepDocument|out-file "$TargetFile.bicep"

}