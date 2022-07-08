<#
    .Synopsis
        Copy an Api from a source Azure Api Management to a target Azure Api Management interactivelyà

    .Description
        Copy an Api from a source Azure Api Management to a target Azure Api Management. It shows
        a menu to help the user to select the source Api and the target Api Management. Ensure to be already logged
        to an Azure subscription using Connect-AzAccount

    .Example
        # Copy an Api from a source Api Management to a target one
        Copy-PSBicepApiManagementApiWithGUI
#>
function Copy-PSBicepApiManagementApiWithGUI()
{
    $ErrorActionPreference = 'Stop'

    try{
        Get-AzContext|Out-Null
    }
    catch{
        connect-azAccount|Out-Null
    }

    function Get-ApiManagement($env){
        Get-AzSubscription | Out-ConsoleGridView -Title "Select $env subscription" -OutputMode Single | Set-AzContext | Out-Null

        $Apim = Get-AzApiManagement | ForEach-Object{
            $obj = "" |Select-Object Name,ResourceGroup, Apim
            $obj.Name = $_.Name
            $obj.ResourceGroup = $_.ResourceGroupName
            $obj.apim = $_
            $obj
        } | Out-ConsoleGridView -Title "Select $env Api Management" -OutputMode Single
        if($null -eq $Apim)
        {
            throw "No Api management service selected"
        }
        $Apim.Apim
    }
    $SubscriptionIdFinder = [regex]'^/subscriptions/(.*?)/.*$'

    $sourceApiManagement = Get-ApiManagement -env 'source'
    $sourceSubscriptionId = $SubscriptionIdFinder.Replace($sourceApiManagement.Id,'$1')

    $sourceVersionSet = $null
    $Response = Read-Host -Prompt 'Do you want to export a single Api version or all versions of an Api? [ONE/all]'
    if($response -ne 'all')
    {
        $sourceApimcontext = New-AzApiManagementContext -ResourceId $sourceApiManagement.Id
        $sourceApiobj = Get-AzApiManagementApi -Context $sourceApimcontext | ForEach-Object{
            $obj = "" |Select-Object Name,Path,ApiVersion,ApiId,Api
            $obj.Name = $_.Name
            $obj.Path = $_.Path
            $obj.ApiVersion = $_.ApiVersion
            $obj.ApiId = $_.ApiId
            $obj.Api = $_
            $obj
        } | Out-ConsoleGridView -Title "Select source Api" -OutputMode Single

        if($null -eq $sourceApiobj)
        {
            throw "No Api selected"
        }

        $sourceApi = $sourceApiobj.Api
        $sourceelement = $sourceApi.ApiId
    }
    else{
        $sourceApimcontext = New-AzApiManagementContext -ResourceId $sourceApiManagement.Id
        $sourceVersionSetObj = Get-AzApiManagementApiVersionSet -Context $sourceApimcontext | ForEach-Object{
            $obj = "" |Select-Object Name,VersionSetId
            $obj.Name = $_.DisplayName
            $obj.VersionSetId = $_.ApiVersionSetId
            $obj
        } | Out-ConsoleGridView -Title "Select source Api Version set" -OutputMode Single

        if($null -eq $sourceVersionSetObj)
        {
            throw "No Api version selected"
        }

        $sourceVersionSet = $sourceVersionSetObj
        $sourceelement = $sourceVersionSet.VersionSetId

    }

    $targetFile = "$Env:temp\$($sourceelement).bicep"

    write-host "Source"
    write-host "    Api Mamanagement"
    write-host "        SubscriptionId: $sourceSubscriptionId"
    write-host "        Resource Group: $($sourceApiManagement.ResourceGroupName)"
    write-host "        Name:           $($sourceApiManagement.Name)"

    if($null -ne $sourceVersionSet){
        write-host "    Api version set"
        write-host "        Name:           $($sourceVersionSet.Name)"
        write-host "        Id:             $($sourceVersionSet.VersionSetId)"
    }
    else{
        write-host "    Api"
        write-host "        Name:           $($sourceApi.Name)"
        write-host "        Version:        $($sourceApi.ApiVersion)"
        write-host "        Id:             $($sourceApi.ApiId)"
    }
    write-host ""
    write-host "Temporary target file: $targetFile"
    write-host ""
    if($null -ne $sourceVersionSet){
        write-host "Executing 'Export-PSBicepApiManagementApiVersionSet -SubscriptionId '$sourceSubscriptionId' -ResourceGroupName '$($sourceApiManagement.ResourceGroupName)' -ApiManagementName '$($sourceApiManagement.Name)' -ApiVersionSetId $($sourceVersionSet.VersionSetId) -TargetFile '$($targetFile)''"
        Export-PSBicepApiManagementApiVersionSet -SubscriptionId $sourceSubscriptionId -ResourceGroupName $sourceApiManagement.ResourceGroupName -ApiManagementName $sourceApiManagement.Name -ApiVersionSetId $sourceVersionSet.VersionSetId -TargetFile $targetFile
    }
    else{
        write-host "Executing 'Export-PSBicepApiManagementApi -SubscriptionId '$sourceSubscriptionId' -ResourceGroupName '$($sourceApiManagement.ResourceGroupName)' -ApiManagementName '$($sourceApiManagement.Name)' -ApiId '$($sourceApi.ApiId)' -TargetFile '$($targetFile)''"
        Export-PSBicepApiManagementApi -SubscriptionId $sourceSubscriptionId -ResourceGroupName $sourceApiManagement.ResourceGroupName -ApiManagementName $sourceApiManagement.Name -ApiId $sourceApi.ApiId -TargetFile $targetFile
    }
    $targetApiManagement = Get-ApiManagement -env 'target'
    $TargetSubscriptionId = $SubscriptionIdFinder.Replace($targetApiManagement.Id,'$1')

    $bicepParameters=@{}
    $BicepDocument =Get-Content $targetFile -raw |ConvertFrom-PSBicepDocument
    foreach($FileParam in $BicepDocument.Params){
        if($FileParam.DefaultValue -ne '''#TargetApiManagement#'''){
            $valueRead=$false
            while(-not $valueRead){
                $message = "Enter value for parameter '$($FileParam.Identifier)'"
                if($null -ne $FileParam.DefaultValue){
                    $message+= " [$($FileParam.DefaultValue)]"
                }
                $Value = Read-Host -Prompt $message
                if([String]::IsNullOrWhiteSpace($Value)){
                    if($null -ne $FileParam.DefaultValue){
                        $value = $FileParam.DefaultValue.Replace("'","")
                    }
                    else{
                        write-host "Please provide a value"
                        continue;
                    }
                }
                $valueRead=$true
                $bicepParameters[$FileParam.Identifier]= $Value
            }
        }
    }

    write-host "Target"
    write-host "    Api Mamanagement"
    write-host "        SubscriptionId: $TargetSubscriptionId"
    write-host "        Resource Group: $($targetApiManagement.ResourceGroupName)"
    write-host "        Name:           $($targetApiManagement.Name)"
    write-host "    Parameters:"
    foreach($key in $bicepParameters.Keys)
    {
        write-host "    Key:            $key"
        write-host "        Value:      $($bicepParameters[$key])"
    }
    write-host ""
    write-host "Executing  'Import-PSBicepApiManagementApi -SubscriptionId '$TargetSubscriptionId' -ResourceGroupName '$($targetApiManagement.ResourceGroupName)' -ApiManagementName '$($targetApiManagement.Name)' -TargetFile '$($targetFile)'' -Parameters $('$bicepParameters')"
    Import-PSBicepApiManagementApi -SubscriptionId $TargetSubscriptionId -ResourceGroupName $targetApiManagement.ResourceGroupName -ApiManagementName $targetApiManagement.Name -TargetFile $targetFile -Parameters $bicepParameters

}