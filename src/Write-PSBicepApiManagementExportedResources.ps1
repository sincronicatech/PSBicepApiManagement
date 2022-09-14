function Write-PSBicepApiManagementExportedResources( 
    $bicepDocument,
    $sourceApiManagement ,
    $ResourcesToBeAnalyzed,
    $ResourcesAnalyzed,
    $TargetFile
    
)
{
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
            if($elementString.Contains($value)){
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
        $newDocument.Add($obj)
    }

    $newDocument|ConvertTo-PSBicepDocument|out-file "$TargetFile"
}