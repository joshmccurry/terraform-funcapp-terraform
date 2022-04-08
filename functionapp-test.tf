terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.99.0"
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
}

resource "azurerm_app_service_plan" "testapp" {
  name                = "azure-functions-test-service-plan"
  location            = azurerm_resource_group.testapp.location
  resource_group_name = azurerm_resource_group.testapp.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_storage_share" "testapp" {
  name                 = "sharename"
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
  }
}

