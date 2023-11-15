
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.80.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = "rg-startse-test-001"
  location = var.location
}


resource "azurerm_container_registry" "this" {
  depends_on = [azurerm_resource_group.this]

  sku                           = "Basic"
  name                          = "rollContainerRegistryTest"
  location                      = var.location
  admin_enabled                 = true
  resource_group_name           = azurerm_resource_group.this.name
  public_network_access_enabled = true
}

resource "azurerm_container_app_environment" "this" {
  depends_on = [azurerm_resource_group.this]

  name                = "roll-dice-api-environment"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
}



resource "azurerm_container_app" "this" {
  depends_on = [azurerm_container_registry.this, azurerm_container_app_environment.this]

  name                         = "roll-dice-api-container"
  revision_mode                = "Single"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id

  secret {
    name  = "registry-password"
    value = azurerm_container_registry.this.admin_password
  }

  registry {
    server               = azurerm_container_registry.this.login_server
    username             = azurerm_container_registry.this.admin_username
    password_secret_name = "registry-password"
  }

  ingress {
    target_port                = 8000
    external_enabled           = true
    allow_insecure_connections = true

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name    = "roll-dice-api"
      image   = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu     = 0.25
      memory  = "0.5Gi"
      args    = []
      command = []
    }

    http_scale_rule {
      name                = "roll-dice-http-scale-rule"
      concurrent_requests = 100
    }
  }
}



