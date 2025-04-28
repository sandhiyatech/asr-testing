param(
    [string]$ResourceGroupName,
    [string]$RecoveryVaultName,
    [string]$VMName
)

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
