set -euo pipefail                                                                                                                                                                                                                        blob-host.s

#Login to Azure
azure_login() {
	echo "[INFO] Checking Azure login..."
	#Check if logged in
	if ! az account show >/dev/null 2>&1; then
 		echo "[INFO] No active session found. Logging in..."
		az login
	else
		echo "[INFO] Already logged in"
	fi

	sub_id=$(az account show --query id -o tsv)
	echo "Subscription ID: $sub_id ✅"
	az account set --subscription "$sub_id"
	echo "[INFO] Azure ready ✅"
}


#validating inputs
validate_inputs() {
	[ -z "$rg" ] && { echo "Resource Group cannot be empty"; exit 1; }
	[ -z "$location" ] && { echo "Location cannot be empty"; exit 1; }
	[ -z "$storage_account" ] && { echo "Storage account cannot be empty"; exit 1; }
	[ -z "$fd" ] && { echo "Front Door name cannot be empty"; exit 1; }
	[ -z "$vnet_name" ] && { echo "VNet name name cannot be empty"; exit 1;}
	[ -z "$subnet_name" ] && { echo "Subnet name cannot be empty"; exit 1;}
	[ -z "$dns_zone" ] && { echo "DNS zone name cannot be empty"; exit 1;}
	[ -z "$fd_profile" ] && { echo "Front Door profile cannot be empty"; exit 1; }
	[ -z "$fd_endpoint" ] && { echo "Front Door endpoint cannot be empty"; exit 1; }
	[ -z "$origin_group" ] && { echo "Origin group cannot be empty"; exit 1; }
	[ -z "$origin_name" ] && { echo "Origin name cannot be empty"; exit 1; }
}



#variables
variables() {
	echo "[INFO] Setting variables for automation..."
	# Resource Group
	rg="kml_rg_main-e0aa467b2be24fc1"

	# Location
	location="eastus"

	# Storage account
	storage_account="mylabstorageforblob"
	cdn_profile="my-cdn-profile"
	cdn_endpoint="my-cdn-endpoint"
	# Front Door
	fd="my-lab-fd"

	# Virtual Network and Subnet
	vnet_name="my-lab-vnet"
	subnet_name="my-lab-subnet"

	# DNS zone
	dns_zone="mylabzone.com"

	# Front Door profile and endpoint
	fd_profile="fd-lab-profile"
	fd_endpoint="fd-lab-endpoint"

	# Front Door origin group and origin
	origin_group="lab-origin-group"
	origin_name="lab-origin"

	echo "[INFO] All variables set."
}

#Create Resource Group
resource_group() {
	echo "[INFO] Checking if Resource Group '$rg' exists..."
	if az group exists --name "$rg"; then
		echo "Resource Group '$rg' already exists. Skipping creation." 
	else
		echo "Creating Resource Group '$rg'..."
		az group create --name "$rg" --location "$location"

	fi

}


#Create private storage Account
create_storage_account() {
	echo "[INFO] Checking if storage account exists..."
	if az storage account show --name "$storage_account" --resource-group "$rg" >/dev/null 2>&1; then
		echo "Storage account already exists. Skipping creation."
	else
		echo "Creating storage account..."
		az storage account create --name "$storage_account" --resource-group "$rg" --location "$location" --sku Standard_LRS --kind StorageV2 --https-only true && echo "Private storage account created succesfully"
	fi
}


#Enable Static Website
enable_static_web() {
	echo "[INFO] Checking if storage account exists..."
	if ! az storage account show --name "$storage_account" --resource-group "$rg" >/dev/null 2>&1; then
        	echo "Storage account does not exist. Cannot enable static website."

		echo "Creating private storage account"
		create_storage_account
	fi

	az storage blob service-properties update --account-name "$storage_account" --static-website --index-document \
  index.html --404-document 404.html --auth-mode login && echo "Static Web enabled: "
}


#Upload website files
upload_web_files() {
	echo "[INFO] Uploading templates and static files..."

	# Upload templates
	if [ -d "templates" ]; then
		echo "[INFO] Uploading templates..."
		az storage blob upload-batch --account-name "$storage_account" --destination '$web/templates' --source ./templates --overwrit	
		echo "[INFO] Uploaded templatessuccessfully ✅"
	else
		echo "[WARNING] templates directory not found"
	fi

 	# Upload static
	if [ -d "static" ]; then
        	echo "[INFO] Uploading static files..."
		az storage blob upload-batch --account-name "$storage_account" --destination '$web/static' --source ./static --overwrite
		echo "[INFO] static file upload completed ✅"

	else
		echo "[WARNING] static directory not found"
	fi
	echo "[INFO] Upload completed ✅"

}


vnet_pe() {
	echo "[INFO] Creating VNet + Subnet..."

	if ! az network vnet show --name "$vnet_name" --resource-group "$rg" >/dev/null 2>&1; then
		az network vnet create --name "$vnet_name" --resource-group "$rg" --location "$location" --address-prefix 10.0.0.0/16 --subnet-name "$subnet_name" --subnet-prefix 10.0.1.0/24
	else
		echo "[INFO] VNet already exists"
	fi

	echo "[INFO] Disabling network policies for subnet..."
	az network vnet subnet update --resource-group "$rg" --vnet-name "$vnet_name" --name "$subnet_name" --disable-private-endpoint-network-policies true

	echo "[INFO] Creating Private DNS zone..."
	az network private-dns zone create --resource-group "$rg" --name "$dns_zone"

	echo "[INFO] Linking DNS with VNet..."
	az network private-dns link vnet create --resource-group "$rg" --zone-name "$dns_zone" --name vnet-link --virtual-network "$vnet_name" --registration-enabled false

	echo "[INFO] Getting Storage account ID..."
	storage_id=$(az storage account show --name "$storage_account" --resource-group "$rg" --query id -o tsv)

	echo "[INFO] Creating Private Endpoint..."
	az network private-endpoint create --name blob-private-endpoint --resource-group "$rg" --vnet-name "$vnet_name" --subnet "$subnet_name" --private-connection-resource-id "$storage_id" --group-id blob --connection-name blob-connection

	echo "[INFO] Attaching Private DNS to Private Endpoint..."
	az network private-endpoint dns-zone-group create --resource-group "$rg" --endpoint-name blob-private-endpoint --name blob-dns-zone-group --private-dns-zone "$dns_zone" --zone-name "$dns_zone"

	echo "[INFO] Private Endpoint setup completed"
}


#Configure Front door
front_door() {
	echo "[INFO] Creating Front Door profile..."
	az afd profile create --resource-group "$rg" --name "$fd_profile" --sku Standard_AzureFrontDoor


	echo "[INFO] Creating Front Door endpoint..."
	az afd endpoint create --resource-group "$rg" --profile-name "$fd_profile" --name "$fd_endpoint"

	echo "[INFO] Creating origin group..."
	az afd origin-group create --resource-group "$rg" --profile-name "$fd_profile" --origin-group-name "$origin_group"

	echo "[INFO] Creating origin with Private Link..."
	az afd origin create --resource-group "$rg" --profile-name "$fd_profile" --origin-group-name "$origin_group" --origin-name "$origin_name" --host-name "$storage_account.blob.core.windows.net" --origin-host-header "$storage_account.blob.core.windows.net" --enable-private-link true --private-link-location "$location" --private-link-resource "$storage_id" --private-link-sub-resource blob

	echo "[INFO] Fetching Private Endpoint Connection ID..."
	pe_id=$(az network private-endpoint-connection list --resource-group "$rg" --name "$storage_account" --type Microsoft.Storage/storageAccounts --query "[0].id" -o tsv)

	if [ -z "$pe_id" ]; then
		echo "[ERROR] Failed to retrieve Private Endpoint connection ID"
		exit 1
	fi

	echo "[INFO] Approving Private Endpoint connection..."
	az network private-endpoint-connection approve --id "$pe_id" --description "Approved by script"

	echo "[INFO] Creating route..."
	az afd route create --resource-group "$rg" --profile-name "$fd_profile" --endpoint-name "$fd_endpoint" --route-name default-route --origin-group "$origin_group" --supported-protocols Https --patterns-to-match "/*" --https-redirect Enabled --forwarding-protocol MatchRequest

	echo "[INFO] Front Door setup completed"
}


#Create CDN
cdn() {
	echo "[INFO] Preparing storage account for CDN..."

    # Check current public access setting
	public_access=$(az storage account show --name "$storage_account" --resource-group "$rg" --query "allowBlobPublicAccess" -o tsv)

	if [ "$public_access" != "true" ]; then
		echo "[WARNING] Public access is disabled. Enabling it for CDN..."

		az storage account update --name "$storage_account" --resource-group "$rg" --allow-blob-public-access true

		echo "[INFO] Public access enabled."
	else

		echo "[INFO] Public access already enabled."
	fi

	echo "[INFO] Creating CDN profile..."
	az cdn profile create --name "$cdn_profile" --resource-group "$rg" --sku Standard_Microsoft

	echo "[INFO] Creating CDN endpoint..."
		az cdn endpoint create --name "$cdn_endpoint" --profile-name "$cdn_profile" --resource-group "$rg" --origin "${storage_account}.z6.web.core.windows.net" --origin-host-header "${storage_account}.z6.web.core.windows.net"

	echo "[INFO] Fetching CDN endpoint URL..."

	cdn_url=$(az cdn endpoint show --name "$cdn_endpoint" --profile-name "$cdn_profile" --resource-group "$rg" --query hostName -o tsv)

	echo "[SUCCESS] Your website is live at:"
	echo "https://$cdn_url"
}




output_url() {
	echo "[INFO] Fetching Front Door endpoint URL..."
	endpoint_url=$(az afd endpoint show --resource-group "$rg" --profile-name "$fd_profile" --endpoint-name "$fd_endpoint" --query hostName -o tsv)

	echo "[INFO] Your website is available at:"
	echo "https://$endpoint_url"
}

read -p "Choose deployment type (cdn/fd): " choice

if [ "$choice" == "cdn" ]; then
	azure_login
	variables
	create_storage_account
	enable_static_web
    	upload_web_files
    	cdn
	#cdn_output_url
elif [ "$choice" == "fd" ]; then
	azure_login
	variables
#	validate_inputs
#	resource_group
	create_storage_account
	enable_static_web
	upload_web_files
    	vnet_pe
    	front_door
    	output_url

else
    echo "Invalid choice"
    exit 1
fi
