# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

#Requires -Version 7.2
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
  [Parameter(Mandatory)][guid]$SubscriptionId,
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]+$')][string]$Location,
  [Parameter(Mandatory)][pscredential]$AdminCredential,
  [ValidatePattern('^[a-z][a-z0-9]{1,7}$')][string]$WorkshopId = "workshop",
  [string]$VmSize = "Standard_D2as_v5",
  [ValidatePattern('^\d+\.\d+\.\d+$')][string]$TerraformVersion = "1.14.5",
  [ValidatePattern('^([01]\d|2[0-3])[0-5]\d$')][string]$ShutdownTime = "1900",
  [string]$OutputDirectory = (Join-Path ([IO.Path]::GetTempPath()) "TerraformWorkshop")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if ($SubscriptionId -eq [guid]::Empty) { throw "Specify a non-empty subscription ID." }
if ([version]$TerraformVersion -lt [version]"1.14.5" -or [version]$TerraformVersion -ge [version]"2.0.0") {
  throw "Use Terraform 1.14.5 or a newer 1.x release."
}
$reservedUsernames = @(
  "administrator", "admin", "user", "user1", "test", "user2", "test1", "user3", "admin1",
  "1", "123", "a", "actuser", "adm", "admin2", "aspnet", "backup", "console", "david",
  "guest", "john", "owner", "root", "server", "sql", "support", "support_388945a0",
  "sys", "test2", "test3", "user4", "user5", "defaultaccount", "wdagutilityaccount"
)
if ($AdminCredential.UserName -notmatch '^[a-zA-Z][a-zA-Z0-9_-]{0,19}\z') {
  throw "AdminCredential must use a local Windows username, for example workshopadmin: 1-20 letters/digits, underscores or hyphens, starting with a letter. Do not use an email or DOMAIN\username. Uppercase letters are allowed."
}
if ($AdminCredential.UserName -in $reservedUsernames) {
  throw "That administrator username is reserved by Azure or Windows. Use a name such as workshopadmin instead of admin or administrator."
}
$password = $AdminCredential.GetNetworkCredential().Password
try {
  $passwordErrors = @(
    if ($password.Length -lt 8) { "too short (requires at least 8 characters)" }
    if ($password -cnotmatch '[A-Z]') { "missing an uppercase letter (A-Z)" }
    if ($password -notmatch '[0-9]') { "missing a number (0-9)" }
    if ($password -notmatch '[\W_]') { "missing a special character" }
  )
  if ($passwordErrors.Count -gt 0) {
    throw "Password rejected: $($passwordErrors -join '; '). Re-enter AdminCredential with Get-Credential before retrying; an existing setup variable keeps the previously entered password."
  }
} finally { $password = $null }

function Invoke-WorkshopAz {
  param([Parameter(Mandatory)][string[]]$Arguments)
  $result = & az @Arguments --only-show-errors --output json 2>&1
  if ($LASTEXITCODE -ne 0) {
    # Provider diagnostics may contain secure deployment values.
    throw "Azure CLI '$($Arguments[0]) $($Arguments[1])' failed (exit $LASTEXITCODE). Check sign-in, Azure permissions and deployment operations in the portal."
  }
  if ($result) { $result -join "`n" | ConvertFrom-Json -Depth 100 }
}

function New-PrivateDirectory {
  param([string]$Path)
  $directory = New-Item -ItemType Directory -Path $Path
  if ($IsWindows) {
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User, [Security.Principal.SecurityIdentifier]::new("S-1-5-18"))) {
      $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $sid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
      ))
    }
    Set-Acl -LiteralPath $directory.FullName -AclObject $acl
  } else {
    & chmod 700 $directory.FullName
    if ($LASTEXITCODE -ne 0) { throw "Cannot restrict permissions on the deployment directory. No credentials have been written." }
  }
  $directory.FullName
}

function Deploy-WorkshopTemplate {
  param([string]$Name, [string]$Template, [hashtable]$Values)
  $parameters = @{}
  foreach ($key in $Values.Keys) { $parameters[$key] = @{ value = $Values[$key] } }
  $path = Join-Path $runDirectory "$Name.parameters.private.json"
  try {
    @{ parameters = $parameters } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8
    Invoke-WorkshopAz @(
      "deployment", "group", "create", "--subscription", "$SubscriptionId",
      "--resource-group", $platformRg, "--name", $Name, "--mode", "Incremental",
      "--template-file", $Template, "--parameters", "@$path"
    )
  } finally {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    $Values.Clear()
    $parameters.Clear()
  }
}

$platformRg = "rg-$WorkshopId-platform"
$vmName = "$WorkshopId-vm"
# WhatIf is offline, including credential validation: no account queries or builds.
if (-not $PSCmdlet.ShouldProcess("$SubscriptionId / $Location / $platformRg / $vmName",
    "Deploy ONE private Windows VM and grant its managed identity subscription-wide Contributor and container Blob Data Contributor")) { return }
foreach ($file in @("platform.bicep", "workstation.bicep", "bootstrap-windows.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) {
    throw "Missing '$file'. Keep New-Workshop.ps1, platform.bicep, workstation.bicep and bootstrap-windows.ps1 together in the same directory."
  }
}
$outputRoot = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory))
$protectedRoot = Get-Item -LiteralPath $PSScriptRoot
for ($ancestor = $protectedRoot; $null -ne $ancestor; $ancestor = $ancestor.Parent) {
  if (Test-Path -LiteralPath (Join-Path $ancestor.FullName ".git")) {
    $protectedRoot = $ancestor
    break
  }
}
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$protectedPrefix = $protectedRoot.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if ($outputRoot.Equals($protectedRoot.FullName, $comparison) -or $outputRoot.StartsWith($protectedPrefix, $comparison)) {
  throw "OutputDirectory must be outside the repository or standalone script directory, in a private non-synchronized location."
}
Get-Command az -ErrorAction Stop | Out-Null
$context = Invoke-WorkshopAz @("account", "show", "--subscription", "$SubscriptionId")
if ($context.id -ne "$SubscriptionId" -or -not $context.tenantId) {
  throw "Azure context does not match the requested subscription. Sign in with az login."
}
$tenantId = [guid]::Parse($context.tenantId).ToString()
$groups = @(Invoke-WorkshopAz @("group", "list", "--subscription", "$SubscriptionId"))
$existingGroup = $groups | Where-Object name -EQ $platformRg
if ($existingGroup -and ($existingGroup.location -ne $Location -or
    -not $existingGroup.tags -or -not $existingGroup.tags.PSObject.Properties["WorkshopId"] -or
    $existingGroup.tags.WorkshopId -ne $WorkshopId -or
    -not $existingGroup.tags.PSObject.Properties["Purpose"] -or $existingGroup.tags.Purpose -ne "SingleWorkstation")) {
  throw "Existing resource group is not this single-workstation deployment in this location. Choose a new WorkshopId."
}
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$runDirectory = New-PrivateDirectory (Join-Path $outputRoot ("{0}-{1}" -f $WorkshopId, [guid]::NewGuid().ToString("N")))
try {
  foreach ($template in @("platform", "workstation")) {
    & az bicep build --file (Join-Path $PSScriptRoot "$template.bicep") --outfile (Join-Path $runDirectory "$template.generated.json")
    if ($LASTEXITCODE -ne 0) { throw "Bicep compilation failed for $template. No resources have been created." }
  }
  foreach ($provider in @("Microsoft.Network", "Microsoft.Compute", "Microsoft.Storage", "Microsoft.DevTestLab")) {
    Invoke-WorkshopAz @("provider", "register", "--namespace", $provider, "--subscription", "$SubscriptionId", "--wait") | Out-Null
  }
  if (-not $existingGroup) {
    Invoke-WorkshopAz @("group", "create", "--subscription", "$SubscriptionId", "--name", $platformRg,
      "--location", $Location, "--tags", "WorkshopId=$WorkshopId", "Purpose=SingleWorkstation") | Out-Null
  }
  $platform = Deploy-WorkshopTemplate -Name "$WorkshopId-platform" -Template (Join-Path $runDirectory "platform.generated.json") -Values @{
    workshopId = $WorkshopId; location = $Location
  }
  $outputs = $platform.properties.outputs
  $desktop = Deploy-WorkshopTemplate -Name "$WorkshopId-vm" -Template (Join-Path $runDirectory "workstation.generated.json") -Values @{
    workshopId = $WorkshopId; location = $Location; vmName = $vmName
    adminUsername = $AdminCredential.UserName; adminPassword = $AdminCredential.GetNetworkCredential().Password
    vmSize = $VmSize; subnetId = $outputs.subnetId.value; storageAccountName = $outputs.storageAccountName.value
    terraformVersion = $TerraformVersion; shutdownTime = $ShutdownTime; bootstrapRevision = [guid]::NewGuid().ToString()
  }
  $principalId = $desktop.properties.outputs.managedIdentityPrincipalId.value
  $scope = "/subscriptions/$SubscriptionId"
  $role = "b24988ac-6180-42a0-ab88-20f7382dd24c"
  $assignments = @(Invoke-WorkshopAz @("role", "assignment", "list", "--subscription", "$SubscriptionId", "--scope", $scope))
  if (-not @($assignments | Where-Object {
      $_.scope -eq $scope -and $_.principalId -eq $principalId -and $_.roleDefinitionId.EndsWith("/$role")
    }).Count) {
    Invoke-WorkshopAz @("role", "assignment", "create", "--subscription", "$SubscriptionId",
      "--assignee-object-id", $principalId, "--assignee-principal-type", "ServicePrincipal", "--role", $role, "--scope", $scope) | Out-Null
  }
  $access = [pscustomobject]@{
    SubscriptionId = "$SubscriptionId"; TenantId = $tenantId; PlatformResourceGroup = $platformRg
    VmName = $vmName; VmUsername = $AdminCredential.UserName; VmId = $desktop.properties.outputs.vmId.value
    ManagedIdentityPrincipalId = $principalId; BastionName = $outputs.bastionName.value
    StorageAccountName = $outputs.storageAccountName.value; ContainerName = $desktop.properties.outputs.containerName.value
    BackendKey = "lab05.tfstate"
  }
  $access | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory "access.json") -Encoding utf8
  Write-Host "Provisioning completed. Password-free settings: $(Join-Path $runDirectory 'access.json')"
  $access
} finally {
  Get-ChildItem -LiteralPath $runDirectory -Filter "*.generated.json" | Remove-Item -Force
}
