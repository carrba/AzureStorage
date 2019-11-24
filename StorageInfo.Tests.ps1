$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# $sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
# . "$here\$sut"

$module = "StorageInfo"
Import-Module "$here\$module.psm1" -force

Describe "StorageInfo Tests" {
    It "has the root module $module.psm1" {
        "$here\$module.psm1" | Should Exist
    }
    it "$module has been loaded" {
        get-module -name $module | Should not be $null
    }
}

$Functions = (
    "get-StorageInfo",
    "get-storageAccountUsage",
    "get-SAUsage",
    "get-container",
    "get-containerfile",
    "get-TotalDataUsed",
    "get-LastModified",
    "get-storageAccountCost",
    "get-azmodule",
    "connect-az"
)

foreach ($function in $functions) {
    Describe "Test Function $function" {
        It "$function should exist" {
            get-command -name $function -module $module | Should not be $null
        }
    }
}

Describe "get-storageAccount" {
    It "Returns Storage Accounts"{
        mock get-azStorageAccount -mockwith {
            $file = get-content "$here\sa.csv"
            $MockSA = $file | ConvertFrom-Csv
            $MockSA
        }
        $ht = @{"region" = "westeurope";
        "kind" = "StorageV2";
        "Accesstier" = "Hot"
        }
        $SA = get-StorageAccount -ht $ht 
        $sa.storageaccountname -imatch "itbcstorage1" | Should be True
    }
}