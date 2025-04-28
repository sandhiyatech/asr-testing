param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$VaultName,
    
    [Parameter(Mandatory = $true)]
    [string]$VMName,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    #[Parameter(Mandatory = $true)]
    #[string]$PolicyName,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$SourceLocation,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetLocation,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetNetworkId,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetSubnetName,
    
    [Parameter(Mandatory = $true)]
    [string]$CacheStorageAccountId,
    
    [Parameter(Mandatory = $true)]
    [string]$ReplicationStorageType,
    
    [string]$ReplicateAvailabilitySet,
    
    [string]$StaticIP
)
$SP_DNAE_SECRET_NPROD= $env:INPUT_CLIENTSECRET
$sp_azure_username= $env:INPUT_CLIENTID

install-module -name az -AllowClobber -Force
Import-Module Az -Force

$SecurePassword = ConvertTo-SecureString -String $SP_DNAE_SECRET_NPROD -AsPlainText -Force 
$Credential = New-Object -TypeName System.Management.Automation. PSCredential -ArgumentList $sp_azure_username, $SecurePassword
Connect-AzAccount ServicePrincipal -Tenant Id "4cc65fd6-9c76-4871-a542-eb12a5a7800c" -Credential $Credential

# Set the context
Write-Host "Setting Azure context to subscription: $SubscriptionId" -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId

# Get the VM
Write-Host "Fetching VM details..." -ForegroundColor Cyan
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName

# Get the replication protected item
Write-Host "Fetching replication protected item..." -ForegroundColor Cyan
$replicatedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainerMapping $VaultName -Name $VMName

if ($null -eq $replicatedItem) {
    Write-Error "Replication protected item not found for VM: $VMName"
    exit 1
}

# Enable replication again
Write-Host "Enabling replication..." -ForegroundColor Yellow

$networkMapping = Get-AzRecoveryServicesAsrNetworkMapping ` 
    | Where-Object { $_.PrimaryNetworkId -eq $TargetNetworkId }

if (-not $networkMapping) {
    Write-Error "Network mapping not found for network ID: $TargetNetworkId"
    exit 1
}

# Prepare NIC config
$nicDetails = @()
foreach ($nic in $vm.NetworkProfile.NetworkInterfaces) {
    $nicConfig = New-AzRecoveryServicesAsrNicConfig ` 
        -NicId $nic.Id ` 
        -RecoveryNicSubnetName $TargetSubnetName ` 
        -RecoveryNicStaticIPAddress $StaticIP ` 
        -PrimaryNic $true

    $nicDetails += $nicConfig
}

$replicationDetails = @{
    VmId                   = $vm.Id
    PolicyId               = (Get-AzRecoveryServicesAsrPolicy -Name "24-hour-retention-policy").Id
    ProtectionContainerId  = (Get-AzRecoveryServicesAsrProtectionContainer -Name $TargetResourceGroupName).Id
    RecoveryResourceGroupId = (Get-AzResourceGroup -Name $TargetResourceGroupName).ResourceId
    RecoveryAvailabilitySetId = $ReplicateAvailabilitySet
    RecoveryCloudServiceId = $null
    RecoveryStorageAccountId = $CacheStorageAccountId
    RecoveryNetworkId      = $TargetNetworkId
    VmDisks                 = @()
    SelectedRecoveryNicConfigurations = $nicDetails
    UseManagedDisks         = $true
    RecoveryAvailabilityType = "AvailabilitySet"
    RecoveryStorageAccountType = $ReplicationStorageType
}

New-AzRecoveryServicesAsrReplicationProtectedItem @replicationDetails

Write-Host "Replication re-enabled successfully for VM: $VMName" -ForegroundColor Green
