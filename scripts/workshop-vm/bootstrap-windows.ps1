# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

[CmdletBinding()]
param(
  [ValidatePattern('^\d+\.\d+\.\d+$')]
  [string]$TerraformVersion = "1.14.5",
  [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z][a-zA-Z0-9_-]{0,19}\z')][string]$VmUsername,
  [Parameter(Mandatory)][guid]$SubscriptionId,
  [Parameter(Mandatory)][guid]$TenantId,
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]{3,24}$')][string]$StorageAccountName,
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$ContainerName,
  [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9-]+$')][string]$PlatformResourceGroup,
  [string]$BootstrapRevision = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$toolsDirectory = "C:\Program Files\TerraformWorkshop"
$downloadDirectory = Join-Path $toolsDirectory ("downloads-" + [guid]::NewGuid().ToString("N"))
$workshopDirectory = "C:\Workshop"
$sharedExtensionsDirectory = Join-Path $toolsDirectory "VSCodeExtensions"
$stage = "preparing directories"
try {
New-Item -ItemType Directory -Force -Path $downloadDirectory, $toolsDirectory, $workshopDirectory, $sharedExtensionsDirectory | Out-Null
if ((Get-Item -LiteralPath $workshopDirectory).Attributes -band [IO.FileAttributes]::ReparsePoint) {
  throw "The workshop workspace must not be a symbolic link or junction."
}

$stage = "configuring the administrator workspace"
$localUser = Get-LocalUser -Name $VmUsername -ErrorAction Stop
$administrators = Get-LocalGroup -SID "S-1-5-32-544"
if (@(Get-LocalGroupMember -Group $administrators).SID -notcontains $localUser.SID) {
  throw "The configured VM account must be a local administrator."
}
$workspaceAcl = Get-Acl -LiteralPath $workshopDirectory
$workspaceAcl.SetAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
  $localUser.SID, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
))
Set-Acl -LiteralPath $workshopDirectory -AclObject $workspaceAcl

function Add-MachinePath {
  param([Parameter(Mandatory)][string]$Path)

  $entries = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" | Where-Object { $_ }
  if ($entries -notcontains $Path) {
    [Environment]::SetEnvironmentVariable("Path", (($entries + $Path) -join ";"), "Machine")
  }
}

function Assert-ValidSignature {
  param([Parameter(Mandatory)][string]$FilePath)

  $signature = Get-AuthenticodeSignature -FilePath $FilePath
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "Installer '$FilePath' does not have a valid Authenticode signature: $($signature.StatusMessage)"
  }
}

function Invoke-Installer {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string]$ArgumentList
  )

  $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru
  if ($process.ExitCode -notin @(0, 3010)) {
    throw "Installer '$FilePath' failed with exit code $($process.ExitCode)."
  }
}

$stage = "installing Terraform"
Write-Output "Installing Terraform $TerraformVersion..."
$terraformZipName = "terraform_${TerraformVersion}_windows_amd64.zip"
$terraformZip = Join-Path $downloadDirectory $terraformZipName
$terraformChecksums = Join-Path $downloadDirectory "terraform_${TerraformVersion}_SHA256SUMS"
$terraformBaseUri = "https://releases.hashicorp.com/terraform/$TerraformVersion"
Invoke-WebRequest -Uri "$terraformBaseUri/$terraformZipName" -OutFile $terraformZip
Invoke-WebRequest -Uri "$terraformBaseUri/terraform_${TerraformVersion}_SHA256SUMS" -OutFile $terraformChecksums

$checksumLine = @(Get-Content $terraformChecksums | Where-Object { $_ -match "^[a-fA-F0-9]{64}\s+$([regex]::Escape($terraformZipName))$" })
if ($checksumLine.Count -ne 1) {
  throw "Terraform checksum for $terraformZipName was not found."
}
$expectedChecksum = ($checksumLine[0] -split "\s+")[0].ToLowerInvariant()
$actualChecksum = (Get-FileHash -Path $terraformZip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualChecksum -ne $expectedChecksum) {
  throw "Terraform checksum verification failed. Expected $expectedChecksum but found $actualChecksum."
}

$terraformDirectory = Join-Path $toolsDirectory "Terraform"
New-Item -ItemType Directory -Force -Path $terraformDirectory | Out-Null
Expand-Archive -Path $terraformZip -DestinationPath $terraformDirectory -Force
Add-MachinePath -Path $terraformDirectory

$stage = "installing Azure CLI"
Write-Output "Installing Azure CLI..."
$azureCliInstaller = Join-Path $downloadDirectory "AzureCLI.msi"
Invoke-WebRequest -Uri "https://aka.ms/installazurecliwindowsx64" -OutFile $azureCliInstaller
Assert-ValidSignature -FilePath $azureCliInstaller
Invoke-Installer -FilePath "msiexec.exe" -ArgumentList "/i `"$azureCliInstaller`" /qn /norestart"

$stage = "installing Git for Windows"
Write-Output "Installing Git for Windows..."
$gitRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" -Headers @{
  Accept = "application/vnd.github+json"
  "User-Agent" = "terraform-workshop-bootstrap"
}
$gitAsset = $gitRelease.assets | Where-Object { $_.name -match "^Git-.*-64-bit\.exe$" } | Select-Object -First 1
if (-not $gitAsset) {
  throw "The current Git for Windows release does not contain a 64-bit installer."
}
$gitInstaller = Join-Path $downloadDirectory $gitAsset.name
Invoke-WebRequest -Uri $gitAsset.browser_download_url -OutFile $gitInstaller
Assert-ValidSignature -FilePath $gitInstaller
Invoke-Installer -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS"

$stage = "installing Visual Studio Code"
Write-Output "Installing Visual Studio Code..."
$vscodeInstaller = Join-Path $downloadDirectory "VSCodeSetup-x64.exe"
Invoke-WebRequest -Uri "https://update.code.visualstudio.com/latest/win32-x64/stable" -OutFile $vscodeInstaller
Assert-ValidSignature -FilePath $vscodeInstaller
Invoke-Installer -FilePath $vscodeInstaller -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath"

$codeCommand = "C:\Program Files\Microsoft VS Code\bin\code.cmd"
if (-not (Test-Path -LiteralPath $codeCommand)) {
  throw "Visual Studio Code installed, but code.cmd was not found at '$codeCommand'."
}
Write-Output "Installing the HashiCorp Terraform VS Code extension..."
& $codeCommand --install-extension "hashicorp.terraform" --force --extensions-dir $sharedExtensionsDirectory --user-data-dir "C:\ProgramData\VSCode\bootstrap-profile"
if ($LASTEXITCODE -ne 0) {
  throw "The HashiCorp Terraform VS Code extension installation failed."
}

$stage = "configuring managed identity authentication"
$settings = @{
  SubscriptionId = "$SubscriptionId"; TenantId = "$TenantId"; StorageAccountName = $StorageAccountName
  ContainerName = $ContainerName; PlatformResourceGroup = $PlatformResourceGroup
  BackendKey = "lab05.tfstate"; TerraformVersion = $TerraformVersion
}
$settings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $toolsDirectory "workshop.json") -Encoding UTF8
foreach ($entry in @{
  ARM_USE_MSI = "true"; ARM_USE_CLI = "false"; ARM_USE_AZUREAD = "true"
  ARM_SUBSCRIPTION_ID = "$SubscriptionId"; ARM_TENANT_ID = "$TenantId"
}.GetEnumerator()) {
  [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "Machine")
}
@"
resource_group_name  = "$PlatformResourceGroup"
storage_account_name = "$StorageAccountName"
container_name       = "$ContainerName"
key                  = "lab05.tfstate"
use_msi              = true
use_azuread_auth     = true
subscription_id      = "$SubscriptionId"
tenant_id            = "$TenantId"
"@ | Set-Content -LiteralPath (Join-Path $toolsDirectory "backend.lab05.hcl") -Encoding UTF8

$authenticationScript = @'
$ErrorActionPreference = "Stop"
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq "S-1-5-18") {
  throw "Run this helper as the signed-in workshop administrator, not SYSTEM."
}
$settings = Get-Content -LiteralPath (Join-Path $PSScriptRoot "workshop.json") -Raw | ConvertFrom-Json
$env:ARM_USE_MSI = "true"
$env:ARM_USE_CLI = "false"
$env:ARM_USE_AZUREAD = "true"
$env:ARM_SUBSCRIPTION_ID = $settings.SubscriptionId
$env:ARM_TENANT_ID = $settings.TenantId
# Clear competing credentials in this shell; Terraform talks directly to the VM identity endpoint.
foreach ($name in @("ARM_CLIENT_ID", "ARM_CLIENT_SECRET", "ARM_CLIENT_CERTIFICATE_PATH", "ARM_CLIENT_CERTIFICATE_PASSWORD",
    "ARM_ACCESS_KEY", "ARM_SAS_TOKEN", "ARM_OIDC_TOKEN", "ARM_OIDC_TOKEN_FILE_PATH")) {
  Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
}
$env:ARM_USE_OIDC = "false"
az login --identity --allow-no-subscriptions --output none --only-show-errors
if ($LASTEXITCODE -ne 0) { throw "Managed identity CLI login failed. Retry from this Azure VM." }
az account set --subscription $settings.SubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Subscription selection failed. Allow RBAC propagation, then rerun this helper." }
Set-Location "C:\Workshop"
Write-Host "Azure CLI and Terraform use this VM's identity. Contributor applies to the ENTIRE subscription." -ForegroundColor Yellow
$settings | Select-Object SubscriptionId, TenantId, StorageAccountName, ContainerName, BackendKey
'@
Set-Content -LiteralPath (Join-Path $toolsDirectory "Connect-WorkshopAzure.ps1") -Value $authenticationScript -Encoding UTF8

$desktopDirectory = [Environment]::GetFolderPath("CommonDesktopDirectory")
$shell = New-Object -ComObject WScript.Shell
$vscodeShortcut = $shell.CreateShortcut((Join-Path $desktopDirectory "VS Code - Terraform Workshop.lnk"))
$vscodeShortcut.TargetPath = "C:\Program Files\Microsoft VS Code\Code.exe"
$vscodeShortcut.Arguments = "`"$workshopDirectory`" --extensions-dir `"$sharedExtensionsDirectory`""
$vscodeShortcut.WorkingDirectory = $workshopDirectory
$vscodeShortcut.Save()

$powershellShortcut = $shell.CreateShortcut((Join-Path $desktopDirectory "Workshop PowerShell.lnk"))
$powershellShortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$powershellShortcut.Arguments = "-NoExit -File `"$toolsDirectory\Connect-WorkshopAzure.ps1`""
$powershellShortcut.WorkingDirectory = $workshopDirectory
$powershellShortcut.Save()

$verificationScript = @'
$ErrorActionPreference = "Stop"
$settings = Get-Content -LiteralPath (Join-Path $PSScriptRoot "workshop.json") -Raw | ConvertFrom-Json
$terraform = & "$PSScriptRoot\Terraform\terraform.exe" version -json
if ($LASTEXITCODE -ne 0) { throw "Terraform verification failed (exit $LASTEXITCODE)." }
if (($terraform | ConvertFrom-Json).terraform_version -ne $settings.TerraformVersion) {
  throw "Installed Terraform version does not match the requested version."
}
$azure = & "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd" version --output json
if ($LASTEXITCODE -ne 0 -or ($azure | ConvertFrom-Json).'azure-cli' -notmatch '^\d+\.\d+\.\d+$') {
  throw "Azure CLI version verification failed."
}
$git = & "C:\Program Files\Git\cmd\git.exe" --version
if ($LASTEXITCODE -ne 0 -or $git -notmatch '^git version \d+\.\d+\.\d+') { throw "Git version verification failed." }
$code = & "C:\Program Files\Microsoft VS Code\bin\code.cmd" --version --user-data-dir "$env:LOCALAPPDATA\TerraformWorkshop\verify-vscode"
if ($LASTEXITCODE -ne 0 -or $code[0] -notmatch '^\d+\.\d+\.\d+') { throw "VS Code version verification failed." }
Write-Host "Verified Terraform $($settings.TerraformVersion), Azure CLI $(($azure | ConvertFrom-Json).'azure-cli'), $git, VS Code $($code[0])." -ForegroundColor Green
'@
Set-Content -Path (Join-Path $toolsDirectory "verify-tools.ps1") -Value $verificationScript -Encoding UTF8
$stage = "verifying installed tool versions"
& (Join-Path $toolsDirectory "verify-tools.ps1")
Write-Output "Workshop VM bootstrap completed successfully ($BootstrapRevision). Open Workshop PowerShell as the workshop administrator for identity login."
} catch {
  Write-Output "Workshop bootstrap failed during $stage. Exception type: $($_.Exception.GetType().Name)."
  Write-Output $_.Exception.Message
  exit 1
} finally {
  if (Test-Path -LiteralPath $downloadDirectory) { Remove-Item -LiteralPath $downloadDirectory -Recurse -Force }
}
