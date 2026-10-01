<!--
SPDX-FileCopyrightText: 2026 biro98
SPDX-License-Identifier: MIT
-->

# Lab 10 Reference Solution

This independent reference implements the complete
[guided exercise](../INSTRUCTIONS.md). See the [architecture and AVM
references](../README.md) for diagrams, feature choices and networking boundaries.
The solution and its optional provider-mocked tests are published for students.
Complete the starter walkthrough before comparing with this reference.

## Safe use

Choose the guide's local-computer or supplied-VM authentication path; neither
requires resources from earlier labs or a remote state backend. When using the
VM, run its helper **before** entering this directory because it changes directory.
After authenticating, return to the repository root and run:

```powershell
Set-Location .\lab10-avm-patterns\solution
if (-not (Test-Path .\terraform.tfvars)) {
  Copy-Item .\terraform.tfvars.example .\terraform.tfvars
}
Get-Location
```

The path must end in `lab10-avm-patterns\solution`. The reference
uses `rg-tf-lab10-ref10` and suffix `ref10`, distinct from the student example.
Personalize both; never reuse the starter/platform/another lab's group.

The code is complete: do not paste construction blocks into it again. From this
directory, run the initialization, validation, plan review, apply, verification
and cleanup sections of the [attendee guide](../INSTRUCTIONS.md#7-initialize-format-validate-and-inspect-the-plan).
Use the same six output names and exact expected inventory.

**Paid resources:** Basic Bastion, Standard NAT, two public IPs, and one DNS
Resolver inbound endpoint. Charges continue until deletion finishes. Firewall,
gateway and DDoS-plan features remain disabled. Do not deploy without budget
approval. Nothing requires changing the existing workshop VM networking.

## Optional local provider-mocked tests

From the solution directory, initialize and validate before running the tests:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform test "-var-file=terraform.tfvars.example" "-filter=tests\contracts.tftest.hcl"
```

Expected: **3 passed, 0 failed**. The runs exercise the baseline pattern,
a preview adding the Queue DNS zone, and restoration of the two-zone input.
Use the supplied example input file for these tests; its Sweden Central region
and two-zone baseline match the fixtures. You can use personalized inputs for
an approved real deployment separately.

Initialization downloads modules/providers; the tests use mocked providers and
do not deploy Azure resources. Ordinary `terraform plan` and `terraform apply`
do not automatically run these tests.

The test's `command = apply` applies only to mocked providers. Mocked output IDs
and region discovery are test fixtures, not credentials or deployable resources.
This is **not** proof of subscription policy, quota, service availability or real
network connectivity. Use the guide's real Azure checks after an approved apply.

Do not publish `.terraform`, populated inputs, state, plans, local validation
artifacts or backend settings with the reference.
