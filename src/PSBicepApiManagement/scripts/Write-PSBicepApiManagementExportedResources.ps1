function Write-PSBicepApiManagementExportedResources( 
    $bicepDocument,
    $sourceApiManagement ,
    $ResourcesToBeAnalyzed,
    $ResourcesAnalyzed,
    $TargetFile,
    [switch]$IncludeWiki,
    $Schema = $null
    
)
{
    $apiManagementCretionResources=@()
    $apiManagementCretionResources+=$ResourcesAnalyzed
    write-host "Searching child resources to be exported"

    $resourceCounter = 0
    while($resourceCounter -lt $ResourcesToBeAnalyzed.Length){ #since there is no native Stack object on Powershell (other than using the .net version), the script will use an array and an incremental index to analyze all data inside the array
        $ResourceToAnalyze = $ResourcesToBeAnalyzed[$resourceCounter];
        $ResourcesToBeAnalyzed += $bicepDocument.Resources|Where-Object{$_.Parent -eq $ResourceToAnalyze.Identifier}
        if($null -ne $Schema -and $ResourceToAnalyze.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apis/operations@')){
            #parametrizing schema
            $toParametrizeSchema =@()
            $toParametrizeSchema+= $ResourceToAnalyze.Attributes.properties.templateParameters
            $toParametrizeSchema+= $ResourceToAnalyze.Attributes.properties.request.representations
            $toParametrizeSchema+= $ResourceToAnalyze.Attributes.properties.request.headers
            $toParametrizeSchema+= $ResourceToAnalyze.Attributes.properties.responses.representations
            $toParametrizeSchema+= $ResourceToAnalyze.Attributes.properties.responses.headers
            foreach($req in $toParametrizeSchema){
                if($null -ne $req.schemaId){
                    $req.schemaId = 'schemaId'
                }
            }
        }
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

    #Looking for sub references
    while($referenceCounter -lt $AllReferredIdentifiers.Count){
        $id = $AllReferredIdentifiers[$referenceCounter]
        write-host "  Current id: $id"
        $referenceCounter+=1
        
        if($exportedIdentifiers -contains $id)
        {
            continue;
        }
        $ReferredOuterResource = Resolve-PSBicepReference -Identifier $id -Document $bicepDocument
        $ResourceToAdd=$null
        if($ReferredOuterResource.ElementType -eq "Resource")
        {
            if($ReferredOuterResource.Name.StartsWith("'")){
                #It is not a variable. it should be variabilized
                $newName = $ReferredOuterResource.Name.Replace("'",'').Replace("-",'_') + "_parameter"
                $ResourcesAnalyzed+= New-PSBicepParam -Identifier $newName -Type string -DefaultValue $ReferredOuterResource.Name
            }
            else{
                $newName = $ReferredOuterResource.Name
            }
            $ResourceToAdd= New-PSBicepResource -Identifier $id -ResourceType $ReferredOuterResource.ResourceType -IsExisting:$true -Name $newName -Parent $ReferredOuterResource.Parent
        }
        else{
            if($ReferredOuterResource.ElementType -eq 'Param' -and $ReferredOuterResource.Identifier -eq $sourceApiManagement.Name){
                $ReferredOuterResource.DefaultValue='''#TargetApiManagement#'''
            }
            $ResourceToAdd=$ReferredOuterResource;
        }
        if($null -ne $ResourceToAdd){
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
    
    }

    if($null -ne $schema){
        $ResourcesAnalyzed+= New-PSBicepParam -Identifier 'schemaId' -Type string
    }

    write-host "Reparametrizing static strings associated to new params"
    $parameters = $resourcesAnalyzed|Where-Object{$_.ElementType -eq 'Param'}
    
    $resourcesToRemove = @()
    $resourcesToAdd = @()

    foreach($parameter in $parameters){
        if($null -eq $parameter.DefaultValue -or $parameter.DefaultValue -eq '#TargetApiManagement#'){
            continue;
        }
        $value = $parameter.DefaultValue
        $elements = $resourcesAnalyzed|Where-Object{$_.ElementType -ne 'Param'}
        foreach($element in $elements) {
            $tempDocument = New-PSBicepDocument
            $tempDocument.Add($element)
            $elementString = ConvertTo-PSBicepDocument -DocumentObject $tempDocument
            #Issue: removing schemas because empty if it has been imported using an openapi file
            if($element.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apis/schemas')){
                $resourcesToRemove += $element;
            } elseif ($elementString.Contains($value)){
                $newElementString = $elementString.Replace($value,$parameter.Identifier)
                $newElement = ConvertFrom-PSBicepDocument -DocumentString $newElementString
                $resourcesToRemove += $element;
                $resourcesToAdd += $newElement.AllObjects[0]
            }
        }

    }

    $newResources = @()
    $newResources += $resourcesToAdd;
    foreach($element in $resourcesAnalyzed) {
        if($resourcesToRemove -contains $element ){
            continue;
        }
        $newResources += $element
    }

    write-host "Writing new bicep document $TargetFile"
    $newDocument = New-PSBicepDocument
    foreach($obj in $newResources){
        if(-not $IncludeWiki -and $null -ne $obj.ResourceType -and $obj.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apis/wikis')){
            
        }
        else{
            $newDocument.Add($obj)
        }
    }

    $newDocument|ConvertTo-PSBicepDocument|out-file "$TargetFile"
    $file = get-item $targetFile

    $baseCreation=@()
    $startingApi = $newDocument.AllObjects|?{$_.ResourceType -ne $null -and $_.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apis@')};
    $baseCreation += $startingApi

    $baseCreation += $newDocument.AllObjects|?{$_.Identifier -eq $startingApi.Parent}
    $baseCreation += $newDocument.AllObjects|?{$_.ResourceType -ne $null -and $_.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apiVersionSets@')};
        
    $baseDocument = New-PSBicepDocument 
    $baseDocument.Params = $newDocument.Params
    foreach($res in $baseCreation){
        $baseDocument.Add($res)
    }
    $minimalCreationDocument = "$($file.BaseName)-onlyApi.bicep"
    write-host "Writing minimal creation document $minimalCreationDocument"
    $baseDocument|ConvertTo-PSBicepDocument|out-file $minimalCreationDocument
    
    $schemaFile = "$($file.BaseName)-schema.json"
    write-host "Writing schema document $schemaFile"
    $schema|Out-File $schemaFile
}