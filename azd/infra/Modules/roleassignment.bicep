param roleDefinitionId string
param principalId string
param resName string
param storageAccount bool
param vault bool

var roleAssignmentName = guid(principalId, roleDefinitionId, resourceGroup().id)

// Get a reference to the storage account creating via the language module
resource extStr 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (storageAccount) {
  name: resName
}

resource extVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (vault) {
  name: resName
}

// Configure the service principal with the required RBAC role for Storage Account
resource roleStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (storageAccount) {
  name: roleAssignmentName
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
  scope: extStr
}

// Configure the service principal with the required RBAC role for Key Vault
resource roleVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (vault && !storageAccount) {
  name: roleAssignmentName
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
  scope: extVault
}
