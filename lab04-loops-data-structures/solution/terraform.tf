# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.14.5, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
