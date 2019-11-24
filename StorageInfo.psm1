function get-StorageInfo {
    [CmdletBinding()]
    <#
    .SYNOPSIS
      Returns Storage Container Info from Azure Storage Accounts
    .EXAMPLE
      get-StorageInfo -region "ukwest" -kind "StorageV2" -Accesstier "Hot"
      get-StorageInfo -kind "Storage"
    .DESCRIPTION
      Azure Storage Info tool to return container storage usage from storage accounts.
      This module requires the Azure AZ module to be installed
    .PARAMETER region
      Limits the search to the specific Azure region, E.g. ukwest, westus2 etc. The Azure cmdlet, 
      Get-AzLocation lists available locations
    .PARAMETER kind
      Limits the search to Storage accounts of the type specified
    .PARAMETER Accesstier
      Limits the search to access tier of hot or cold
    .PARAMETER MB
      Switch to display aggregate container data value in megabytes.
    .PARAMETER GB
      Switch to display aggregate container data value in gigabytes.
    .NOTES
      https://github.com/carrba/AzureStorage
#>
    param (
        $region = $null,
        [Parameter()]
        [ValidateSet('StorageV2','Storage','BlobStorage','BlockBlobStorage','FileStorage')]
        [AllowNull()]
        $Kind = $Null,
        [Parameter()]
        [ValidateSet('hot','cold')]
        [AllowNull()]
        $AccessTier = $Null,
        [switch]$MB,
        [switch]$GB
    )
    # Check for Az.Storage module
    if (get-azmodule) { 
        # Check/connect to AZure account
        connect-az

        # Create hastable to pass to function Get-StroageAccounts
        $ht = @{}
        # Set variables to $Null where -eq ""
        if ($region -eq ""){$region = $Null}
        if ($kind -eq ""){$kind = $null}
        if ($Accesstier -eq ""){$kind = $null}
        $ht = @{"region" = $region;
                "kind" = $Kind;
                "Accesstier" = $AccessTier
            }

        # Get a list of Storage Accounts to query
        $SA = Get-StorageAccount -ht $ht
        
        # Run Get-storageAccountUsage against filtered StorageAccounts
        get-storageAccountUsage -StorageAccount $SA -MB:$MB -GB:$GB
    } 
    else {
        Write-Warning "AZ.Storage module is required. Please install PowerShell AZ module (install-module az)"
    }
}

function get-StorageAccount {
    [CmdletBinding()]
    <#
    .SYNOPSIS
      Returns Storage Accounts of the current subscription
    .EXAMPLE
      get-StorageAccount
      get-storageaccount -ht @{"regions" = "westeurope"; "kind" = "StorageV2"; "AccessTier" = "hot"}
      get-storageaccount -ht @{"regions" = "ukwest"; "kind"}
    .DESCRIPTION
      Returns Storage Accounts from the current subscription. A hashtable can be supplied as a parameter to filter the result. 
      The avaialabe hash table keys are regions, kind and accesstier.
    .PARAMETER HT
      Filter results by supplying a hashtable with these optininal keys: Regions, kind and/or accesstier 
    .NOTES
      https://github.com/carrba/AzureStorage
    #>
    param (
        [hashtable]$ht
    )
    $storageAccounts = Get-AzStorageAccount
    if ($null -ne $ht.region){
        $StorageAccounts = $StorageAccounts | Where-Object location -eq $ht.region
    }
    if ($null -ne $ht.kind){
        $StorageAccounts = $StorageAccounts | Where-Object kind -eq $ht.kind
    }
    if ($null -ne $ht.AccessTier){
        $StorageAccounts = $StorageAccounts | Where-Object AccessTier -eq $ht.AccessTier
    }
    $StorageAccounts
}

function get-storageAccountUsage {
    param (
        $StorageAccount,
        [switch]$MB,
        [switch]$GB
    )
    foreach ($SA in $StorageAccount){
        get-SAUsage -StorageContext $SA.Context -MB:$MB -GB:$GB
    }
}

function get-SAUsage{
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

function get-azmodule {
    $mod = get-module -ListAvailable | where-object name -eq "AZ.Storage"
    if ($mod){
        $true
    }
    else {
        $false
    }
}
function connect-az {
    try {
        Get-AzSubscription -ErrorAction stop | Out-Null
    }
    catch {
        Connect-AzAccount
    }
}