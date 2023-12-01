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
    Set-AzContext -SubscriptionId $SubscriptionId|Out-Null

    $deploymentName = "ApiDeployment-$((get-date).ToString('yyyy-MM-dd_hh-mm-ss'))"

    if($Confirm -eq $true)
    {
        New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $file -TemplateParameterObject $bicepParameters -WhatIf
        $Response = Read-Host -Prompt 'Continue? [NO/yes]'
        if($response -ne 'yes')
        {
            return
        }
    }
    try{
        New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $file  -TemplateParameterObject $bicepParameters -Verbose 
    }
    catch{
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