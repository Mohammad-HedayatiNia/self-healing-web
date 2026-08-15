// =============================================================================
// Module: vmss.bicep
// Linux VM Scale Set that is the actual "self-healing" mechanism:
//   - Application Health Extension reports per-instance health on port 80.
//   - automaticRepairsPolicy watches that health signal and replaces any
//     instance that goes Unhealthy (which is exactly what happens when you
//     terminate/delete/stop an instance) — no manual action needed.
// N+1 is satisfied by defaulting capacity to 2 behind the single LB rule.
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Name prefix used for all resources in this module')
param namePrefix string

@description('Number of VM instances (N+1 => minimum 2)')
@minValue(2)
param instanceCount int = 2

@description('VM SKU. Small burstable size keeps this well under the AUD 20/month target.')
param vmSize string = 'Standard_B1s'

@description('Admin username for the VMs')
param adminUsername string

@description('SSH public key for the admin user')
@secure()
param sshPublicKey string

@description('Subnet resource ID from the network module')
param subnetId string

@description('Load balancer backend address pool ID from the loadbalancer module')
param backendPoolId string

@description('Base64-encoded cloud-init custom data used to bootstrap the web page')
param customData string

@description('Tags applied to every resource')
param tags object = {}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: '${namePrefix}-vmss'
  location: location
  tags: tags
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: false
    singlePlacementGroup: false
    platformFaultDomainCount: 1
    upgradePolicy: {
      mode: 'Automatic'
    }
    automaticRepairsPolicy: {
      enabled: true
      gracePeriod: 'PT10M'
      repairAction: 'Replace'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'web'
        adminUsername: adminUsername
        customData: customData
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: sshPublicKey
              }
            ]
          }
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'ubuntu-24_04-lts'
          sku: 'server'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          diskSizeGB: 30
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${namePrefix}-nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: '${namePrefix}-ipcfg'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: backendPoolId
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'ApplicationHealthLinux'
            properties: {
              publisher: 'Microsoft.ManagedServices'
              type: 'ApplicationHealthLinux'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              settings: {
                protocol: 'http'
                port: 80
                requestPath: '/'
                intervalInSeconds: 5
                numberOfProbes: 2
              }
            }
          }
        ]
      }
    }
  }
}

output vmssId string = vmss.id
output vmssName string = vmss.name
