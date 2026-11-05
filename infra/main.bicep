@allowed(['dev', 'prod'])
param env string = 'dev'
param location string = resourceGroup().location
param skuName string = 'Standard_LRS'

var storageName = 'st${env}${uniqueString(resourceGroup().id)}'

resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: {
    project: 'lab-bicep'
    environment: env
  }
  sku: { name: skuName }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

output storageName string = st.name
