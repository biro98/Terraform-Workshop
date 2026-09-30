# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

terraform {
  # INTENTIONAL ISSUE: constrain the Terraform and AzureRM versions.
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}
