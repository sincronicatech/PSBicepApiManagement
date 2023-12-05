#workaround for https://github.com/Azure/azure-powershell/issues/19399

function Export-PSBicepApiManagementSubscriptionData (
    $resourceGroupName,
    $apiManagementName,
    $ApiId
)
{
    $context = New-AzApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $apiManagementName
    $api = Get-AzApiManagementApi -Context $context -ApiId $apiId
    if($null -eq $api.SubscriptionKeyHeaderName){
        return $null
    }
    $toReturn = @{}
    $toReturn['header'] = "'$($api.SubscriptionKeyHeaderName)'"
    $toReturn['query'] = "'$($api.SubscriptionKeyQueryParamName)'"

    return $toReturn
}