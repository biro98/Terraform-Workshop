# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

# VM bootstrap supplies ARM authentication and registers required providers.
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
