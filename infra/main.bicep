// =============================================================================
// main.bicep — Auto-healing web tier
//
// Orchestrates three modules:
//   network.bicep      -> VNet / subnet / NSG
//   loadbalancer.bicep -> Standard LB (frontend IP, probe, rule, outbound rule)
//   vmss.bicep         -> Linux VMSS with Application Health Extension +
//                          automatic instance repairs (the self-healing part)
//
// Deploy with:
//   az deployment group create -g <rg> -f infra/main.bicep -p infra/main.bicepparam
// Plan only (no changes made) with:
//   az deployment group what-if -g <rg> -f infra/main.bicep -p infra/main.bicepparam
// =============================================================================

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Short prefix used to name every resource, e.g. "shweb"')
@minLength(3)
@maxLength(10)
param namePrefix string = 'shweb'

@description('Environment tag, e.g. dev/test/prod')
param environment string = 'dev'

@description('Number of VM instances behind the load balancer (N+1 => minimum 2)')
@minValue(2)
param instanceCount int = 2

@description('VM SKU for the scale set instances')
param vmSize string = 'Standard_B1s'

@description('Admin username for the VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for the admin user (paste your id_rsa.pub / id_ed25519.pub contents)')
@secure()
param sshPublicKey string

@description('CIDR allowed to reach SSH (22). Restrict this to your own IP in real use.')
param sshSourceCidr string = 'Internet'

var tags = {
  project: 'self-healing-web-tier'
  environment: environment
  managedBy: 'bicep'
  owner: 'mohammad'
}

// cloud-init that installs and starts NGINX's default welcome page.
// See cloud-init/docker-ghcr.yaml for the bonus containerised variant —
// swap the loadTextContent path below to use it instead.
var customData = base64(loadTextContent('../cloud-init/nginx-default.yaml'))

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    location: location
    namePrefix: namePrefix
    sshSourceCidr: sshSourceCidr
    tags: tags
  }
}

module loadbalancer 'modules/loadbalancer.bicep' = {
  name: 'deploy-loadbalancer'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module vmss 'modules/vmss.bicep' = {
  name: 'deploy-vmss'
  params: {
    location: location
    namePrefix: namePrefix
    instanceCount: instanceCount
    vmSize: vmSize
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    subnetId: network.outputs.subnetId
    backendPoolId: loadbalancer.outputs.backendPoolId
    customData: customData
    tags: tags
  }
}

output webUrl string = 'http://${loadbalancer.outputs.publicIpAddress}'
output webFqdn string = loadbalancer.outputs.publicIpFqdn
output vmssName string = vmss.outputs.vmssName
