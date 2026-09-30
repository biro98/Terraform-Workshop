# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

location            = "swedencentral"
unique_suffix       = "ref04"
resource_group_name = "rg-tf-lab04-ref04"
subnets = {
  application       = { address_prefix = "10.10.1.0/24" }
  data              = { address_prefix = "10.10.2.0/24" }
  private_endpoints = { address_prefix = "10.10.3.0/24" }
}
