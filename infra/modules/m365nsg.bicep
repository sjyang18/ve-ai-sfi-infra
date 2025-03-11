param networkSecurityGroupName string = 'm365nsg'
param tags object = {}
var location = resourceGroup().location

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: networkSecurityGroupName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'M365-NetIso-AllowRAv3SAWGateways'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'M365RemoteDesktopGateway'
          sourceAddressPrefixes: []
          sourcePortRange: '*'
          sourcePortRanges: []
          destinationAddressPrefix: '*'
          destinationAddressPrefixes: []
          destinationPortRange: '3389'
          destinationPortRanges: []
          description: 'Created by M365 Core Network Security managed policy. Please see https://aka.ms/M365NetIsoWiki for more info.'
        }
      }
      {
        name: 'M365-NetIso-AllowVirtualNetwork'
        properties: {
          priority: 101
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourceAddressPrefixes: []
          sourcePortRange: '*'
          sourcePortRanges: []
          destinationAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefixes: []
          destinationPortRange: '*'
          destinationPortRanges: []
          description: 'Created by M365 Core Network Security managed policy. Please see https://aka.ms/M365NetIsoWiki for more info.'
        }
      }
      {
        name: 'M365-NetIso-AllowPortsFromSAWs'
        properties: {
          priority: 102
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'CorpNetSaw'
          sourceAddressPrefixes: []
          sourcePortRange: '*'
          sourcePortRanges: []
          destinationAddressPrefix: '*'
          destinationAddressPrefixes: []
          destinationPortRange: '*'
          destinationPortRanges: []
          description: 'Created by M365 Core Network Security managed policy. Please see https://aka.ms/M365NetIsoWiki for more info.'
        }
      }
      {
        name: 'M365-NetIso-AllowTorusManagement'
        properties: {
          priority: 103
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefixes: [
            '13.107.6.152/31'
            '13.107.9.152/31'
            '13.107.18.10/31'
            '13.107.19.10/31'
            '13.107.128.0/22'
            '23.103.160.0/20'
            '23.103.224.0/19'
            '40.96.0.0/13'
            '40.104.0.0/15'
            '52.96.0.0/14'
            '70.37.151.128/25'
            '111.221.112.0/21'
            '131.253.33.215/32'
            '132.245.0.0/16'
            '134.170.68.0/23'
            '150.171.32.0/22'
            '157.56.96.16/28'
            '157.56.96.224/28'
            '157.56.232.0/21'
            '157.56.240.0/20'
            '191.232.96.0/19'
            '191.234.6.152/32'
            '191.234.140.0/22'
            '191.234.224.0/22'
            '204.79.197.215/32'
            '206.191.224.0/19'
          ]
          sourcePortRange: '*'
          sourcePortRanges: []
          destinationAddressPrefix: '*'
          destinationAddressPrefixes: []
          destinationPortRange: '9796'
          destinationPortRanges: []
          description: 'Created by M365 Core Network Security managed policy. Please see https://aka.ms/M365NetIsoWiki for more info.'
        }
      }
      {
        name: 'M365-NetIso-AllowLoadBalancer'
        properties: {
          priority: 104
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourceAddressPrefixes: []
          sourcePortRange: '*'
          sourcePortRanges: []
          destinationAddressPrefix: '*'
          destinationAddressPrefixes: []
          destinationPortRange: '*'
          destinationPortRanges: []
          description: 'Created by M365 Core Network Security managed policy. Please see https://aka.ms/M365NetIsoWiki for more info.'
        }
      }
      {
        name: 'M365-NetIso-DenyTorusManagementFromInternet'
        properties: {
          priority: 105
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourceAddressPrefixes: []
          sourcePortRange: '*'
          sourcePortRanges: []
          destinationAddressPrefix: '*'
          destinationAddressPrefixes: []
          destinationPortRange: '9796'
          destinationPortRanges: []
          description: 'Created by M365 Core Network Security managed policy. Please see https://aka.ms/M365NetIsoWiki for more info.'
        }
      }
      {
        name: 'M365-NetIso-DenyHighRiskPorts'
        properties: {
          priority: 106
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourceAddressPrefixes: []
          sourcePortRange: '*'
          sourcePortRanges: []
          destinationAddressPrefix: '*'
          destinationAddressPrefixes: []
          destinationPortRange: ''
          destinationPortRanges: [
            '13'
            '17'
            '19'
            '20'
            '21'
            '22'
            '23'
            '53'
            '69'
            '111'
            '115'
            '119'
            '123'
            '135'
            '137'
            '138'
            '139'
            '161'
            '162'
            '389'
            '445'
            '512'
            '514'
            '593'
            '873'
            '1337'
            '1433'
            '1434'
            '1900'
            '3306'
            '3389'
            '3637'
            '4333'
            '5353'
            '5432'
            '5601'
            '5723'
            '5724'
            '5800'
            '5900'
            '5984'
            '5985'
            '5986'
            '6379'
            '6984'
            '7000'
            '7001'
            '7199'
            '7473'
            '7474'
            '7687'
            '8888'
            '9042'
            '9142'
            '9160'
            '9200'
            '9300'
            '9798'
            '9987'
            '11211'
            '15000'
            '16379'
            '19888'
            '26379'
            '27017'
            '27018'
            '27019'
            '28017'
            '42080'
            '50030'
            '50060'
            '50070'
            '50090'
            '50075'
            '50111'
            '61620'
            '61621'
            '3702'
            '19000'
            '19080'
          ]
          description: 'Created by M365 Core Network Security managed policy. Please see https://aka.ms/M365NetIsoWiki for more info.'
        }
      }
    ]
  }
}

output id string = networkSecurityGroup.id
