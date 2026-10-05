provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cursor-team-pool"
      Phase       = "a"
      ManagedBy   = "terraform"
      cursor-pool = var.pool_name
    }
  }
}

provider "dns" {}
