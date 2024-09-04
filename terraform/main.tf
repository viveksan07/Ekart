resource "azurerm_resource_group" "aks_rg" {
  name     = "aks-resource-group"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "aks-cluster"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "akscluster"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "development"
  }
}

# Assign AcrPull role to the AKS managed identity
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = azurerm_kubernetes_cluster.aks_cluster.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = "/subscriptions/7f64bf91-2d58-4a80-ae8e-da09dee3825d/resourceGroups/aks-resource-group/providers/Microsoft.ContainerRegistry/registries/testingacr001"
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)
}

resource "kubernetes_deployment" "coronavirus_tracker" {
  metadata {
    name = "coronavirus-tracker"
    labels = {
      app = "coronavirus-tracker"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "coronavirus-tracker"
      }
    }
    template {
      metadata {
        labels = {
          app = "coronavirus-tracker"
        }
      }
      spec {
        container {
          name  = "coronavirus-tracker"
          image = "testingacr001.azurecr.io/coronavirus-tracker:latest"
          image_pull_policy = "Always"
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "coronavirus_tracker_service" {
  metadata {
    name = "coronavirus-tracker-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment.coronavirus_tracker.spec[0].template[0].metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "LoadBalancer"
  }
}
