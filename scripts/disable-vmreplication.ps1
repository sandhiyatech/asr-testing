param(
    [string]$ResourceGroupName,
    [string]$RecoveryVaultName,
    [string]$VMName
)
$SP_DNAE_SECRET_NPROD= $env:INPUT_CLIENTSECRET
$sp_azure_username= $env:INPUT_CLIENTID

install-module -name az -AllowClobber -Force
Import-Module Az -Force

$SecurePassword = ConvertTo-SecureString -String $SP_DNAE_SECRET_NPROD -AsPlainText -Force 
$Credential = New-Object -TypeName System.Management.Automation. PSCredential -ArgumentList $sp_azure_username, $SecurePassword
Connect-AzAccount ServicePrincipal -Tenant Id "4cc65fd6-9c76-4871-a542-eb12a5a7800c" -Credential $Credential

# Connect to the ASR vault
$vault = Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroupName -Name $RecoveryVaultName
Set-AzRecoveryServicesAsrVaultContext -Vault $vault

# Find the replicated item (VM)
$replicatedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem | Where-Object { $_.FriendlyName -eq $VMName }

if ($replicatedItem) {
    # Disable replication
    Remove-AzRecoveryServicesAsrReplicationProtectedItem -InputObject $replicatedItem -Force
    Write-Output "Replication disabled for VM: $VMName"
} else {
    Write-Error "Replicated item not found for VM: $VMName"
}
