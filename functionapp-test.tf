terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.3.0"
    }
  }
}

resource "azurerm_resource_group" "testapp" {
  name     = format("testfunctionapp-%s", substr(uuid(), 0, 4))
  location = "East US"
}

resource "azurerm_storage_account" "testapp" {
  name                = format("testfunctionappstore%s", lower(substr(uuid(), 0, 4)))
  resource_group_name      = azurerm_resource_group.testapp.name
  location                 = azurerm_resource_group.testapp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    default_action             = "Allow"
    virtual_network_subnet_ids = [azurerm_subnet.testapp.id]
  }
}

resource "azurerm_service_plan" "testapp" {
  name                = "azure-functions-test-service-plan"
  location            = azurerm_resource_group.testapp.location
  resource_group_name = azurerm_resource_group.testapp.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_storage_share" "testapp" {
  name                 = format("sharename-%s", lower(substr(uuid(), 0, 4)))
  storage_account_name = azurerm_storage_account.testapp.name
  quota                = 50
}


resource "azurerm_function_app" "testapp" {
  name                       = format("testfunctionapp-%s", substr(uuid(), 0, 4))
  location                   = azurerm_resource_group.testapp.location
  resource_group_name        = azurerm_resource_group.testapp.name
  app_service_plan_id        = azurerm_app_service_plan.testapp.id
  storage_account_name       = azurerm_storage_account.testapp.name
  storage_account_access_key = azurerm_storage_account.testapp.primary_access_key
  version                    = "~4"
  app_settings = {
    "WEBSITE_CONTENTSHARE" = azurerm_storage_share.testapp.name
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.testapp.primary_connection_string
    "WEBSITE_CONTENTOVERVNET" = "1"
  }
  site_config {
    always_on = "true"
    vnet_route_all_enabled = "true"
  }
}

resource "azurerm_network_security_group" "testapp" {
  name                = "example-security-group"
  location            = azurerm_resource_group.testapp.location
  resource_group_name = azurerm_resource_group.testapp.name
}

resource "azurerm_virtual_network" "testapp" {
  name                 = format("testvnet-%s", substr(uuid(), 0, 4))
  location            = azurerm_resource_group.testapp.location
  resource_group_name = azurerm_resource_group.testapp.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "testapp" {
  name                 = format("testsubnet-%s", substr(uuid(), 0, 4))
  resource_group_name  = azurerm_resource_group.testapp.name
  virtual_network_name = azurerm_virtual_network.testapp.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Web", "Microsoft.Storage"]
  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    }
  }
}
resource "azurerm_app_service_virtual_network_swift_connection" "testapp" {
  app_service_id = azurerm_function_app.testapp.id
  subnet_id      = azurerm_subnet.testapp.id
}

