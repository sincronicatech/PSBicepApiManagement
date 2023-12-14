<#
    .Synopsis
        Import a bicep file containin a version set or an api to a target api management instance

    .Description
        Import a bicep file to a target api management instance.

    .Parameter SubcriptionId
        Subcription id containing the target Api Management instance

    .Parameter ResourceGroupName
        Name of the resource group containing the target Api Management instance

    .Parameter TargetFile
        Path of the source Bicep file

    .Parameter Parameters
        Hashtable containing all params referred in the bicep file. Please note that the Api Management name param is handled automatically by the cmdlet

    .Parameter Confirm
        If true, shows the changes before applying, asking for confirmation.

    .Example
        # Exports an Api
        Export-PSBicepApiManagementApiVersionSet -SubscriptionId '00000000-1111-2222-3333-444444444444' -ResourceGroupName 'Api-management-CICD' -ApiManagementName 'Api-management-src' -ApiVersionSetId '62a8b0a2ccab053b96e10e3f' -TargetFile .\ApiVSExport.bicep

#>
function Import-PSBicepApiManagementApi (
    $SubscriptionId ,
    $ResourceGroupName ,
    $ApiManagementName ,
    $TargetFile,
    $Parameters=@{},
    $Confirm=$true
)

{
    $ErrorActionPreference= 'Stop'
    #Import-Module PSBicepParser

    $file = "$targetFile"
    $bicepParameters = @{}
    
    $BicepDocument =Get-Content $file -raw |ConvertFrom-PSBicepDocument
    foreach($FileParam in $BicepDocument.Params){
        if($FileParam.DefaultValue -eq '''#TargetApiManagement#'''){
            $bicepParameters[$FileParam.Identifier] = $ApiManagementName;
        }
        else{
            if($Parameters.ContainsKey($FileParam.Identifier))
            {
                $bicepParameters[$FileParam.Identifier]=$Parameters[$FileParam.Identifier]
            }
        }
    }

    write-host "Connecting to Subscription Id $SubscriptionId"
    get-azcontext -ListAvailable|Where-Object{$_.Subscription.Id -eq $SubscriptionId}|select-azcontext|out-null


    $deploymentName = "ApiDeployment-$((get-date).ToString('yyyy-MM-dd_hh-mm-ss'))"

    if($Confirm -eq $true)
    {
        if((test-path "$fullPath-schema.json") -and (test-path "$fullPath-onlyApi.bicep.support")){
            write-host "Schema file found"
            New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $file -TemplateParameterObject $bicepParameters -WhatIf -Verbose -schema 'tempschema'
        }
        else{
            New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $file -TemplateParameterObject $bicepParameters -WhatIf -Verbose
        }

        
        $Response = Read-Host -Prompt 'Continue? [NO/yes]'
        if($response -ne 'yes')
        {
            return
        }
    }
    try{
        $fileInfo = dir $file
        $fullPath = $fileinfo.FullName.Substring(0,$fileinfo.FullName.Length-$fileinfo.Extension.Length)

        if((test-path "$fullPath-schema.json") -and (test-path "$fullPath-onlyApi.bicep.support")){
            Move-Item  "$fullPath-onlyApi.bicep.support"  "$fullPath-onlyApi.bicep"
            try{
                write-host "Schema file found"
            
                $BicepDocumentMinimal =Get-Content "$fullPath-onlyApi.bicep" -raw |ConvertFrom-PSBicepDocument
                $api = $BicepDocumentMinimal.AllObjects|?{$null -ne $_.ResourceType -and $_.ResourceType.StartsWith('''Microsoft.ApiManagement/service/apis@')}
                $apiId = $api.name.Replace('''','')
                write-host "  Ensuring Api $apiId"
                $bicepParameters['schemaId']='temporary'
                New-AzResourceGroupDeployment -Name "$deploymentName-OnlyApi" -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile "$fullPath-onlyApi.bicep" -TemplateParameterObject $bicepParameters -Verbose|out-null    
            }
            finally{
                #reverting file
                Move-Item  "$fullPath-onlyApi.bicep"  "$fullPath-onlyApi.bicep.support"
            }
            
            write-host "  Importing schema $apiId"
            $context = New-AzApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $apiManagementName
            $api = Get-AzApiManagementApi -Context $context -ApiId $apiId
            $fileInfo = dir "$fullPath-schema.json"
            Import-AzApiManagementApi -Context $context -ApiId $apiId -SpecificationFormat OpenApiJson -SpecificationPath $fileInfo.FullName -Path $api.Path|out-null
            $schema = Get-AzApiManagementApiSchema -Context $context -ApiId $apiId
            write-host "    Schema id: $($schema.SchemaId)"
            if($null -ne $schema.schemaid){
                $bicepParameters['schemaId']=$schema.SchemaId
            }
        }
    
        New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $file  -TemplateParameterObject $bicepParameters -Verbose |out-null
    }
    catch{
        write-host "Errore: $($_.Exception.Message)"
        write-host $_.ScriptStackTrace
        $operations =Get-AzResourceGroupDeploymentOperation -DeploymentName $deploymentName -ResourceGroupName $ResourceGroupName
        $failedOperations = $operations|Where-Object{$_.StatusCode -ne 'OK'}
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("Errors during deployment:")
        foreach($op in $failedOperations){
            $sb.AppendLine("  TargetResource : $($op.TargetResource)")
            $sb.AppendLine("    Code         : $($op.StatusCode)")
            $sb.AppendLine("    Message      : $($op.StatusMessage)")
        }
        Write-Host $sb.ToString()
        
        Write-Error "Error importing api"
        return $operations
    }
}