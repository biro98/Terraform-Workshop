# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

# VM bootstrap supplies managed-identity credentials and registers providers.
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}
