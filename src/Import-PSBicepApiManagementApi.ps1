
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
    Import-Module PSBicepParser.Powershell

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

    if($force -ne $true)
    {
        New-AzResourceGroupDeployment -Name "ApiDeployment-$((get-date).ToString('yyyy-MM-dd_hh-mm-ss'))" -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $file -TemplateParameterObject $bicepParameters -WhatIf
        $Response = Read-Host -Prompt 'Continue? [NO/yes]'
        if($response -ne 'yes')
        {
            return
        }
    }

    New-AzResourceGroupDeployment -Name "ApiDeployment-$((get-date).ToString('yyyy-MM-dd_hh-mm-ss'))" -ResourceGroupName $ResourceGroupName -Mode Incremental -TemplateFile $file  -TemplateParameterObject $bicepParameters -Verbose
}