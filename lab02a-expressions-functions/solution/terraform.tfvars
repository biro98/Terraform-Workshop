# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

project_name   = "Payments Platform"
environment    = "dev"
unique_suffix  = "rv02a"
base_cidr      = "10.20.0.0/16"
subnet_newbits = 8
subnet_names   = ["Application", "Data", "Private Endpoints"]
extra_tags = {
  cost_center = "training"
  owner       = "network-team"
}