
function Import-PSBicepApiManagementApi (
    $SubscriptionId ,
    $ResourceGroupName ,
    $ApiManagementName ,
    $TargetFile,
    $force,
    $parameters=@{}
)

{
    $ErrorActionPreference= 'Stop'
    Import-Module PSBicepParser

    $file = "$targetFile.bicep"
    $bicepParameters = @{}

    $BicepDocument =Get-Content $file -raw |ConvertFrom-PSBicepDocument
    foreach($FileParam in $BicepDocument.Params){
        if($FileParam.DefaultValue -eq '''#TargetApiManagement#'''){
            $bicepParameters[$FileParam.Identifier] = $ApiManagementName;
        }
        else{
            if($parameters.ContainsKey($FileParam.Identifier))
            {
                $bicepParameters[$FileParam.Identifier]=$parameters[$FileParam.Identifier]
            }
        }
    }

    write-host "Connecting to Subscription Id $SubscriptionId"
    Set-AzContext -SubscriptionId $SubscriptionId|Out-Null

    $deploymentName = "ApiDeployment-$((get-date).ToString('yyyy-MM-dd_hh-mm-ss'))"

    if($force -ne $true)
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
        Write-Error $sb.ToString() -ErrorAction Continue
        return $operations
    }
}