terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mel-ciscolabs-com"
    workspaces {
      name = "dev-cpoc-coolsox-iks-2"
    }
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    thousandeyes = {
      source = "william20111/thousandeyes"
    }
  }
}

### Remote State - Import Kube Config ###
data "terraform_remote_state" "iks-2" {
  backend = "remote"

  config = {
    organization = "mel-ciscolabs-com"
    workspaces = {
      name = "iks-cpoc-syd-demo-2"
    }
  }
}

### Decode Kube Config ###
# Assumes kube_config is passed as b64 encoded
locals {
  kube_config = yamldecode(base64decode(data.terraform_remote_state.iks-2.outputs.kube_config))
}

### Providers ###
provider "kubernetes" {
  # alias = "iks-k8s"
  host                   = local.kube_config.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}

provider "thousandeyes" {
  token = var.te_token # Passed from Workspace Variable
}


### Deploy application via Helm through custom module ###

module "coolsox" {
  source = "github.com/cisco-apjc-cloud-se/terraform-helm-coolsox"

  smm_enabled       = true
  panoptica_enabled = false

  appd = {
    application = {
      name = "coolsox2-rw"
    }
    account = {
      host          = format("%s.saas.appdynamics.com", var.appd_account_name)
      name          = var.appd_account_name       # Passed from Workspace Variable
      key           = var.appd_account_key        # Passed from Workspace Variable
      otel_api_key  = var.appd_otel_api_key       # Passed from Workspace Variable
      username      = var.appd_account_username   # Passed from Workspace Variable
      password      = var.appd_account_password   # Passed from Workspace Variable
    }
    db_agent = {
      enabled     = true
      name        = "coolsox2-dbagent"
      databases   = {
        mongodb = {
          name = "mongodb"
          user = "appdagent"
          password = var.appd_account_password
        }
      }
    }
  }

  helm = {
    namespace     = "coolsox"
    release_name  = "coolsox"
    repository    = "https://github.com/cisco-apjc-cloud-se/app-fso-coolsox/raw/main/application/helm/"
    chart         = "coolsox"
    version       = "0.2.2" # In Helm Chart!
    wait          = false
    timeout       = 900
  }

  settings = {
    kubernetes = {
      repository                = "public.ecr.aws/j8r8c0y6/coolsox"
      image_pull_policy         = "Always"
      read_only_root_filesystem = false # breaks AppD Java Agents?
    }
    carts = {
      version   = "1.0.0"
      replicas  = 1
    }
    catalogue_db = {
      version   = "1.0.0"
    }
    catalogue = {
      version       = "1.0.0"
      replicas      = 1
      appd_tiername = "catalogue"
    }
    frontend = {
      version                  = "1.0.0"
      replicas                 = 1
      appd_browser_rum_enabled = false
      ingress = {
        enabled = true
        url = "fso-demo-app2.cisco.com"
      }
      loadbalancer = {
        enabled = false
      }
    }
    orders = {
      version   = "1.0.0"
      replicas  = 1
    }
    payment = {
      version       = "1.0.0"
      replicas      = 1
      appd_tiername = "payment"
    }
    queue = {
      version   = "1.0.0"
    }
    shipping = {
      version   = "1.0.0"
      replicas  = 1
    }
    user_db = {
      version   = "1.0.0"
    }
    user = {
      version       = "1.0.0"
      replicas      = 1
      appd_tiername = "user"
    }
    load_test = {
      enabled       = true
      version       = "1.0.0"
      replicas      = 1
    }
  }

}

### Add Monitoring from ThousandEyes to Public URL ###

# module "thousandeyes_tests" {
#   ### NOTE:  Requires any Cloud Agents to have access to api.thousandeyes.com ###
#   source = "github.com/cisco-apjc-cloud-se/terraform-thousandeyes-tests"
#
#   http_tests = {
#     frontend = {
#       enabled = true # BUG: Can only be true.  Need to disable in GUI
#       name = "cpoc-coolsox-frontend"
#       url = "http://fso-demo-app2.cisco.com"
#
#       network_measurements    = true  # BUG: Can only be true.  Need to disable in GUI
#       mtu_measurements        = true  # BUG: Can only be true.  Need to disable in GUI
#       bgp_measurements        = true  # BUG: Can only be true.  Need to disable in GUI
#       agents = [
#         "Auckland, New Zealand",
#         "Brisbane, Australia",
#         "Melbourne, Australia",
#         "Melbourne, Australia (Azure australiasoutheast)",
#         "Perth, Australia",
#         "Sydney, Australia",
#         "Wellington, New Zealand"
#       ]
#     }
#   }
# }
#
# output "test" {
#   value = module.thousandeyes_tests.test
# }
