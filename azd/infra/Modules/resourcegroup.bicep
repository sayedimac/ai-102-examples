targetScope = 'subscription'

param location string
param name string
// For azd deployments
param envName string

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: name
  location: location
  tags: {
    SecurityControl: 'Ignore'
    'azd-env-name': envName
  }
}

output resourceGroup object = rg
