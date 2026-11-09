terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.28.1"
    }
  }

  # The state holds the tunnel and API token secrets: keep it in the repository's ignored
  # .local/ folder. Run tofu in this folder, or with -chdir from the repository root.
  backend "local" {
    path = "../../../../.local/cloudflare/dev.tfstate"
  }
}

# Reads CLOUDFLARE_API_TOKEN from the environment.
provider "cloudflare" {}
