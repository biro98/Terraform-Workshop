# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

provider "azapi" {
  skip_provider_registration = true
}
