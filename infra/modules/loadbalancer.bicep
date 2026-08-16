// =============================================================================
// Module: loadbalancer.bicep
// Standard SKU public Load Balancer: frontend IP, backend pool, health probe,
// LB rule (80 -> 80) and an explicit outbound rule so VMSS instances (which
// have no public IP of their own) get outbound internet access — required
// for apt/docker pulls during cloud-init on a Standard LB.
//
// Note: the LB rule sets disableOutboundSnat = true because Azure requires
// this whenever the same frontend IP configuration is also referenced by an
// explicit outbound rule (which it is here) — otherwise deployment fails with
// LoadBalancingRuleMustDisableSNATSinceSameFrontendIPConfigurationIsReferencedByOutboundRule.
// =============================================================================

@description('Azure region for all resources')
param location string

@description('Name prefix used for all resources in this module')
param namePrefix string

@description('Tags applied to every resource')
param tags object = {}

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${namePrefix}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${namePrefix}-web-${uniqueString(resourceGroup().id)}')
    }
  }
}

resource lb 'Microsoft.Network/loadBalancers@2023-11-01' = {
  name: '${namePrefix}-lb'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'feConfig'
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'beWebPool'
      }
    ]
    probes: [
      {
        name: 'httpProbe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'httpRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${namePrefix}-lb', 'feConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${namePrefix}-lb', 'beWebPool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${namePrefix}-lb', 'httpProbe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
          disableOutboundSnat: true
        }
      }
    ]
    outboundRules: [
      {
        name: 'outboundInternet'
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${namePrefix}-lb', 'feConfig')
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${namePrefix}-lb', 'beWebPool')
          }
          protocol: 'All'
          allocatedOutboundPorts: 10000
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

output loadBalancerId string = lb.id
output backendPoolId string = lb.properties.backendAddressPools[0].id
output publicIpAddress string = pip.properties.ipAddress
output publicIpFqdn string = pip.properties.dnsSettings.fqdn
