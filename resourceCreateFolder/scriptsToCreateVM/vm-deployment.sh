#!/bin/bash
set -euo pipefail

# Load variables from external file
source ./variables.sh 

# Create a resource group and select the location
echo "Creating resource group: $RESOURCE_GROUP in location: $LOCATION"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create a virtual network and subnet
echo "Creating virtual network: $VNET_NAME and subnet: $SUBNET_NAME"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --subnet-name $SUBNET_NAME

# Create network security group and rules
echo "Creating network security group for the VM"
az network nsg create \
    --resource-group $RESOURCE_GROUP \
    --name "${VM_NAME}NSG" \
    --location $LOCATION

# Create NSG rules to allow HTTP, HTTPS, and SSH from specific IP ranges
echo "Creating NSG rules to allow HTTP, HTTPS, and SSH from specific IP ranges"
az network nsg rule create \
    --nsg-name "${VM_NAME}NSG" \
    --name "Allow-Http" \
    --priority 1001 \
    --resource-group $RESOURCE_GROUP \
    --protocol Tcp --direction Inbound \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 80 \
    --access Allow

az network nsg rule create \
    --nsg-name "${VM_NAME}NSG" \
    --name "Allow-Https" \
    --priority 1002 \
    --resource-group $RESOURCE_GROUP \
    --protocol Tcp --direction Inbound \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 443 \
    --access Allow

az network nsg rule create \
    --nsg-name "${VM_NAME}NSG" \
    --name "AllowSSH" \
    --priority 1003 \
    --resource-group $RESOURCE_GROUP \
    --protocol Tcp --direction Inbound \
    --source-address-prefixes $(curl -s ifconfig.me)/32 --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 22 \
    --access Allow

# Create public IP address 
echo "Creating public IP address for the VM"
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM_NAME}PublicIP" \
  --sku standard \
  --allocation-method Static \
  --location $LOCATION

# Create network interface and associate with NSG
echo "Creating network interface for the VM and associating with NSG"
az network nic create \
    --resource-group $RESOURCE_GROUP \
    --name "${VM_NAME}NIC" \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_NAME \
    --network-security-group "${VM_NAME}NSG" \
    --public-ip-address "${VM_NAME}PublicIP" \
    --location $LOCATION    

# Create VM 
echo "Creating virtual machine: $VM_NAME"
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --nics "${VM_NAME}NIC" \
    --image $IMAGE \
    --size $VM_SIZE \
    --admin-username $ADMIN_USERNAME \
    --generate-ssh-keys \
    --location $LOCATION

