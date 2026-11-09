terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.28.1"
    }
  }

  # State in a private Cloudflare R2 bucket through the S3 API. It holds the tunnel and API token
  # secrets. Credentials come from AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (an R2 API token);
  # ../deploy.sh sets them from R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY.
  backend "s3" {
    bucket = "joakimia-homelab-tfstate"
    key    = "cloudflare/dev.tfstate"
    region = "auto"
    endpoints = {
      s3 = "https://3b6718ee730844e8a9bb34cc5f4bb639.r2.cloudflarestorage.com"
    }
    use_path_style = true
    # R2 is not AWS: no STS, IAM, EC2 metadata, or AWS regions, and no AWS checksum headers.
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    # Lock with a <key>.tflock object written with If-None-Match, which R2 supports.
    use_lockfile = true
  }
}

# Reads CLOUDFLARE_API_TOKEN from the environment.
provider "cloudflare" {}
