#All the variables below must be set correctly for this to work. Please double check each one. The ones "hard set" in this script will rarely ever change if at all.
#The paramters that are unique to each run, or could be different often are asked at the beginning of the run.


#Subscription ID where the server resides:
$subscriptionId = ""

#Azure resource location. All resources used in this script must be the same location (VM, backup vault, and key vault):
$location = "East US"

#Azure Key vault name:
$keyVaultName = ""

#AAD Application Name (see Azure AD Applications):
$aadAppName = ""
$aadClientSecret = ""


#Notes:
#Encrypting VM's original script/doc: https://docs.microsoft.com/en-us/azure/security-center/security-center-disk-encryption  (Caution: This document is horribly out of date)
#AAD App Key Vault Permssions: https://msdn.microsoft.com/en-us/library/mt603625.aspx



########################################################################################################################
########################################################################################################################
Clear-Host

#Get the resource group of the vm
$resourceGroupName = Read-Host -Prompt "Enter the resource group of the VM to encrypt"

#Get the server name to encrypt
$vmName = Read-Host -Prompt "Enter VM Name to encrypt"

#For easier tracing of the encryption chain, it was decided to name the KeK the same as the server, however, if this is no longer desired (encrypt everything under a single KeK), then change this to an input.
$keyEncryptionKeyName = $vmName

#Log into Azure
Write-Host "Logging into Azure..."  
Login-AzureRmAccount -ErrorAction "Stop" 1> $null

#Select the subscription as specified above
Write-Host "Selecting subscription..."
Select-AzureRmSubscription -SubscriptionId $subscriptionId -ErrorAction Stop

# Check if AAD app with $aadAppName was already created
Write-Host "Looking up AAD app..."
$SvcPrincipals = (Get-AzureRmADServicePrincipal -SearchString $aadAppName)
if($SvcPrincipals) {
    $aadClientID = $SvcPrincipals[0].ApplicationId
    if(-not $aadClientSecret) {
        $aadClientSecret = Read-Host -Prompt "Input the client secret for $aadAppName and hit ENTER. It can be retrieved from the AAD portal"
        }
    if(-not $aadClientSecret) {
        Write-Error "An AAD application secret must be provided. Exiting..."
        Exit
    }
}else{
    Write-Error "Cannot find AAD application: ($aadAppName). Please set the variable to the correct app name first, then re-run script."
    Exit
}


#Make sure the resource group exists.
Write-Host "Checking for resource group..."
Try 
    {
    $resGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue;
    }
    Catch [System.ArgumentException]
    {
        Write-Host "Couldn't find resource group: ($resourceGroupName). Make sure the variable is defined to the correct resource group.";
        Exit
    }

#Make sure the key vault exists.
Write-Host "Checking for key vault..."
Try
    {
        $keyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue;
    }
    Catch [System.ArgumentException]
    {
        Write-Host "Couldn't find Key Vault: ($keyVaultName). Make sure the variable is defined to the correct key vault.";
        Exit
    }  
    $diskEncryptionKeyVaultUrl = $keyVault.VaultUri;
	$keyVaultResourceId = $keyVault.ResourceId;

#Make sure the KeK exists.
Write-Host "Checking for KeK..."
if($keyEncryptionKeyName) {
    Try
    {
        $kek = Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyEncryptionKeyName -ErrorAction SilentlyContinue;
    }
    Catch [Microsoft.Azure.KeyVault.KeyVaultClientException]
    {
        Write-Host "Couldn't find key encryption key named : $keyEncryptionKeyName in Key Vault: $keyVaultName";
        $kek = $null;
    } 
    
    if(-not $kek) {
        Write-Host "Creating new key encryption key named: $keyEncryptionKeyName in Key Vault: $keyVaultName";
        $kek = Add-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyEncryptionKeyName -Destination Software -ErrorAction SilentlyContinue;
        Write-Host "Created  key encryption key named: $keyEncryptionKeyName in Key Vault: $keyVaultName";
    }
    $keyEncryptionKeyUrl = $kek.Key.Kid;
}   

########################################################################################################################
########################################################################################################################
Write-Host "Make sure this is the VM you want to encrypt!" -ForegroundColor Yellow
Write-Host "`t VM Name:               $vmName" -ForegroundColor Green
Write-Host
Write-Host "Please double check all of these values:" -ForegroundColor Yellow
Write-Host "`t Subscription ID:       $subscriptionId" -ForegroundColor Green
Write-Host "`t Location:              $location" -ForegroundColor Green
Write-Host "`t Resource Group:        $resourceGroupName" -ForegroundColor Green
Write-Host "`t AAD App Name:          $aadAppName" -ForegroundColor Green
Write-Host "`t AAD Client Secret:     $aadClientSecret" -ForegroundColor Green
Write-Host "`t Key Vault Name:        $keyVaultName" -ForegroundColor Green
Write-Host "`t KeK Name (vm name):    $keyEncryptionKeyName" -ForegroundColor Green
Write-Host
Write-Host "Please double check that none of these values are empty:" -ForegroundColor Yellow
Write-Host "`t KeK URL:               $keyEncryptionKeyUrl" -ForegroundColor Green
Write-Host "`t Key Vault Resource ID: $keyVaultResourceId" -ForegroundColor Green
Write-Host "`t Key Vault URL:         $diskEncryptionKeyVaultUrl" -ForegroundColor Green
Write-Host "`t AAD Client ID:         $aadClientID" -ForegroundColor Green
Write-Host
Write-Host "Please Press [Enter] if everything above is correct." -ForegroundColor Yellow
Read-Host

#Encrypt!
Write-Host "Setting up and starting encryption on VM... Please wait..."
Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $vmName -VolumeType All -AadClientID $aadClientID -AadClientSecret $aadClientSecret -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId -KeyEncryptionKeyUrl $KeyEncryptionKeyUrl -KeyEncryptionKeyVaultId $KeyVaultResourceId
Write-Host "If there were no errors in setup, encryption will continue in the background. You can check the status on the server. Exiting."

########################################################################################################################
#End script