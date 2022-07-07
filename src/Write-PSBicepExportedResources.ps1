function Write-PSBicepExportedResources( 
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
            if($ReferredOuterResource.Name.StartsWith("'")){
                #It is not a variable. it should be variabilized
                $newName = $ReferredOuterResource.Name.replace("'",'') + "_parameter"
                $ResourcesAnalyzed+= New-PSBicepParam -Identifier $newName -Type string -DefaultValue $ReferredOuterResource.Name
            }
            else{
                $newName = $ReferredOuterResource.Name
            }
            $ResourceToAdd= New-PSBicepResource -Identifier $id -ResourceType $ReferredOuterResource.ResourceType -IsExisting:$true -Name $newName
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

    write-host "Writing new bicep document $TargetFile"
    $newDocument = New-PSBicepDocument
    foreach($obj in $resourcesAnalyzed){
        $newDocument.Add($obj)
    }

    $newDocument|ConvertTo-PSBicepDocument|out-file "$TargetFile"
}