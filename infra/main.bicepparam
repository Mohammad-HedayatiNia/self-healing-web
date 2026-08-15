using 'main.bicep'

param location = 'southeastasia' // Azure for Students / region-restricted subscriptions: override with
                                  // -p location=<region> using your subscription's allowed regions
                                  // (see README "Region availability" — check via `az policy assignment show`)
param namePrefix = 'shweb'
param environment = 'dev'
param instanceCount = 2
param vmSize = 'Standard_B1s'
param adminUsername = 'azureuser'
// Do NOT commit a real key here. Pass at deploy time instead, e.g.:
//   az deployment group create ... -p sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"
param sshPublicKey = ''
param sshSourceCidr = 'Internet'
