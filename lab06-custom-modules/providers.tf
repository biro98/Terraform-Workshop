# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

# VM bootstrap sets ARM_USE_MSI=true, ARM_SUBSCRIPTION_ID, and ARM_TENANT_ID.
# Provider authentication is independent from any remote backend configuration.
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}
