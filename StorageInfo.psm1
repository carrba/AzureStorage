# $sa = Get-AzStorageAccount

# Upload a file to blob
# Set-AzStorageBlobContent -file ..\..\Athletics\IMG_3579.MOV -Container $con1.name -Blob IMG_3579.MOV -Context $sa[1].Context 

function get-storageAccount {
    param (
        [string]$region,
        [Parameter()]
        [ValidateSet('StorageV2','Storage','BlobStorage','BlockBlobStorage','FileStorage')][string]$Kind,
        [Parameter()]
        [ValidateSet('hot','cold')][string]$AccessTier,
        [switch]$MB,
        [switch]$GB
    )
    $storageAccounts = Get-AzStorageAccount 
    if ($region){
        $StorageAccounts = $StorageAccounts | Where-Object location -eq $region
    }
    if ($kind){
        $StorageAccounts = $StorageAccounts | Where-Object kind -eq $kind
    }
    if ($AccessTier){
        $StorageAccounts = $StorageAccounts | Where-Object AccessTier -eq $AccessTier
    }
    foreach ($StorageAccount in $StorageAccounts){
        get-StorageAccountUsage -StorageContext $StorageAccount.Context -MB:$MB -GB:$GB
    }
}

function get-StorageAccountUsage{
    param (
        [Microsoft.WindowsAzure.Commands.Common.Storage.AzureStorageContext]$StorageContext,
        [switch]$MB,
        [switch]$GB
    )
    $containers = get-container -StorageContext $StorageContext
    $StorageAccountCost = get-storageAccountCost -StorageAccountName $StorageContext.StorageAccountName
    $Title = "Storage Account : " + $StorageAccountCost.StorageAccountName
    write-host $title
    $Cost = "Cost in current billing period : £" + $StorageAccountCost.BillingCost
    write-host $Cost
    foreach ($container in $containers) {
        get-containerfile -StorageContext $StorageContext.Context -Container $container -MB:$MB -GB:$GB
    }
}
function get-container {
    param (
        [Microsoft.WindowsAzure.Commands.Common.Storage.AzureStorageContext]$StorageContext
    )
    Get-AzStorageContainer -Context $StorageContext.Context
}


function get-containerfile {
    param (
        [Microsoft.WindowsAzure.Commands.Common.Storage.AzureStorageContext]$StorageContext,
        $Container,
        [switch]$MB,
        [switch]$GB
    )
    $listofblobs = Get-AzStorageBlob -Container $container.Name -Context $StorageContext
    $FileCount = $listofblobs.length
    $TotalDataUsed = get-TotalDataUsed -listofblobs $listofblobs
    $LastModified = get-LastModified -listofblobs $listofblobs
    $TitleSize = "TotalFileSize"
    if ($MB){
        $TotalDataUsed = $TotalDataUsed / 1MB
        $TitleSize = $TitleSize + "(MB)"
    }
    elseif ($GB){
        $TotalDataUsed = $TotalDataUsed / 1GB
        $TitleSize = $TitleSize + "(GB)"
    }
    
    $props = @{ "ContainerName" = $Container.Name
                $TitleSize = $TotalDataUsed
                "NumberOfFiles" = $FileCount
                "CreationDate" = $Container.lastmodified
                "LastModifiedDate" = $LastModified}

    $myObj = New-Object -TypeName PSObject -Property $props
    $myObj
}

Function get-TotalDataUsed {
    param (
        [array]$listofblobs
    )
    foreach ($blob in $listofblobs){
        $TotalSize += $blob.length
    }
    $TotalSize
}

function get-LastModified {
    param (
        [array]$listofblobs
    )
    foreach ($blob in $listofblobs){
        if ($lastmod -lt $blob.lastmodified.utcdatetime){
            $lastmod = $blob.lastmodified.utcdatetime
        }
    }
    $lastmod
}

function get-storageAccountCost {
    param (
        [string]$StorageAccountName
    )
    $UsageDetails = Get-AzConsumptionUsageDetail -expand meterdetails -instanceName  $StorageAccountName
    foreach ($item in $UsageDetails){
        $TotalCost += $item.PretaxCost
    }
    $TotalCost
    $props = @{ "StorageAccountName" = $StorageAccountName
                "BillingCost" = $TotalCost}

    $myObj = New-Object -TypeName PSObject -Property $props
    $myObj
}
