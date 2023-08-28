﻿function Generate-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length
    )

    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()

    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)

    $rng.GetBytes($bytes)

    $result = New-Object char[]($length)

    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i]%$charSet.Length]
    }

    return -join $result
}

# Generate a secure password
$securePassword = ConvertTo-SecureString -String (Generate-RandomPassword 10) -AsPlainText -Force


#Read more: https://www.sharepointdiary.com/2020/04/powershell-generate-random-password.html#ixzz8Bi4xSZ4w

$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

Import-Module Azure -ErrorAction SilentlyContinue
$version = 0;

#DEPLOYMENT OPTIONS
#Please review the azuredeploy.json file for available options
$RGName        = "<YOUR RESOURCE GROUP>"
$DeployRegion  = "<SELECT AZURE REGION>"
$AssetLocation = "https://github.com/vanderbilt-redcap/redcap-azure/blob/master/azuredeploy.json"

$parms = @{
    "initials" = "redcap"
    #Alternative to the zip file above, you can use REDCap Community credentials to download the zip file.
    "redcapCommunityUsername"     = "<REDCap Community site username>";
    "redcapCommunityPassword"     = "<REDCap Community site password>";
    "redcapAppZipVersion"         = "<REDCap version";

    #Mail settings
    "fromEmailAddress"            = "<email address listed as sender for outbound emails>";
    "smtpFQDN"                    = "<what it says>"
    "smtpUser"                    = "<login name for smtp auth>"
    "smtpPassword"                = "<password for smtp auth>"

    #Azure Web App
    "siteName"                    = "<WEB SITE NAME, like 'redcap'>";
    "skuName"                     = "S1";
    "skuCapacity"                 = 1;

    #MySQL
    "administratorLogin"          = "<MySQL admin account name>";
    "administratorLoginPassword"  = $securePassword;

    "databaseForMySqlCores"       = 2;
    "databaseForMySqlFamily"      = "Gen5";
    "databaseSkuSizeMB"           = 5120;
    "databaseForMySqlTier"        = "GeneralPurpose";
    "mysqlVersion"                = "5.7";

    #Azure Storage
    "storageType"                 = "Standard_LRS";
    "storageContainerName"        = "redcap";

    #GitHub
    "repoURL"                     = "https://github.com/vanderbilt-redcap/redcap-azure.git";
    "branch"                      = "master";
}
#END DEPLOYMENT OPTIONS

#Dot-sourced variable override (optional, comment out if not using)
$dotsourceSettings = "$($env:PSH_Settings_Files)redcap-azure.ps1"
if (Test-Path $dotsourceSettings) {
    . $dotsourceSettings
}

#ensure we're logged in
Get-AzureRmContext -ErrorAction Stop

#deploy
$TemplateFile = "$($AssetLocation)?x=$version"

try {
    Get-AzureRmResourceGroup -Name $RGName -ErrorAction Stop
    Write-Host "Resource group $RGName exists, updating deployment"
}
catch {
    $RG = New-AzureRmResourceGroup -Name $RGName -Location $DeployRegion
    Write-Host "Created new resource group $RGName."
}
$version ++
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -TemplateParameterObject $parms -TemplateFile $TemplateFile -Name "RedCAPDeploy$version"  -Force -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    $siteName = $deployment.Outputs.webSiteFQDN.Value
    start "https://$($siteName)/AzDeployStatus.php"
    Write-Host "---------"
    $deployment.Outputs | ConvertTo-Json

} else {
    $deperr = Get-AzureRmResourceGroupDeploymentOperation -DeploymentName "RedCAPDeploy$version" -ResourceGroupName $RGName
    $deperr | ConvertTo-Json
}

$endTime=Get-Date

Write-Host ""
Write-Host "Total Deployment time:"
New-TimeSpan -Start $startTime -End $endTime | Select Hours, Minutes, Seconds
