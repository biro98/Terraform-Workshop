# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

# Follow Steps 5 and 6 in README.md. Create locals that:
# 1. Normalize project_name with trimspace, lower, and replace.
# 2. Build a name prefix with a conditional expression for prod/nonprod.
# 3. Transform subnet_names into a map with a for expression. Derive each
#    address_prefix with cidrsubnet and a representative host IP with cidrhost.
# 4. Mark names containing "private" and filter those entries from a second map.
# 5. Merge required tags with extra_tags and format a readable summary string.

# Then create terraform_data.network_plan. Set its input to an object containing
# the name prefix, all subnets, routed subnets, tags, and summary.