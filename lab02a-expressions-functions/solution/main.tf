# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

locals {
  # Read inside out: trim outer whitespace, lowercase the name, then replace spaces
  # with hyphens. For example, " Payments Platform " becomes "payments-platform".
  normalized_project_name = replace(lower(trimspace(var.project_name)), " ", "-")

  # Compare the lowercase environment with "prod". The conditional returns "prod"
  # when true, or "nonprod" otherwise; both dev and test belong to nonprod.
  environment_tier = lower(var.environment) == "prod" ? "prod" : "nonprod"

  # Join the normalized project, environment tier, and supplied suffix with hyphens.
  # The supplied inputs produce "payments-platform-nonprod-rv02a".
  name_prefix = join("-", [local.normalized_project_name, local.environment_tier, var.unique_suffix])

  # Build a map with one calculated object per subnet name.
  subnets = {
    # index starts at 0. Before =>, lowercase the name and replace spaces with
    # underscores to create keys such as "application" and "private_endpoints".
    for index, name in var.subnet_names : lower(replace(name, " ", "_")) => {
      # Add subnet_newbits to the parent prefix length and select subnet index.
      # With 10.20.0.0/16 and 8 extra bits, indexes 0, 1, 2 give consecutive /24s.
      address_prefix = cidrsubnet(var.base_cidr, var.subnet_newbits, index)

      # First calculate the subnet, then select host offset 4: e.g. 10.20.1.4.
      # This calculates an address only; it does not allocate or reserve an IP.
      representative_ip = cidrhost(cidrsubnet(var.base_cidr, var.subnet_newbits, index), 4)

      # Mark names containing "private", ignoring case. This is a naming-based
      # classification for the exercise, not creation of a private endpoint.
      private_endpoint = strcontains(lower(name), "private")
    }
  }

  # Create a second map without changing the original subnet map.
  routed_subnets = {
    # Keep each key and object only when its private_endpoint flag is false.
    # ! means "not"; the supplied inputs keep application and data.
    # This filters data only; it does not configure network routes.
    for key, subnet in local.subnets : key => subnet
    if !subnet.private_endpoint
  }

  # Merge optional tags first and required tags last. Later maps win on duplicate
  # keys, so extra_tags cannot override environment or managed_by.
  common_tags = merge(var.extra_tags, {
    # Normalize the environment tag to lowercase, e.g. "DEV" becomes "dev".
    environment = lower(var.environment)
    managed_by  = "terraform"
  })

  # length counts map entries. format inserts the prefix at %s and counts at %d.
  # With the supplied inputs, the summary ends with "3 subnets (2 routed)".
  summary = format("%s defines %d subnets (%d routed)", local.name_prefix, length(local.subnets), length(local.routed_subnets))
}

# Store the calculated object in Terraform state for plan/apply/state practice.
# This built-in resource creates no Azure resources.
resource "terraform_data" "network_plan" {
  input = {
    name_prefix    = local.name_prefix
    subnets        = local.subnets
    routed_subnets = local.routed_subnets
    tags           = local.common_tags
    summary        = local.summary
  }
}