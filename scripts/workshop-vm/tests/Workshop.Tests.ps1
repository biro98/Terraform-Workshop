# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

$sourceDirectory = Split-Path $PSScriptRoot -Parent
if (Test-Path Function:\az) { throw "Run tests in a fresh process without a custom az function." }

Describe "Single workstation provisioning (offline)" {
  BeforeEach {
    # An isolated repository layout exercises the private-output boundary without writing outside TestDrive.
    $repository = Join-Path $TestDrive "repository"
    $scriptDirectory = Join-Path (Join-Path $repository "scripts") "workshop-vm"
    New-Item -ItemType Directory -Path $scriptDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repository ".git") -Force | Out-Null
    foreach ($file in @("New-Workshop.ps1", "platform.bicep", "workstation.bicep", "bootstrap-windows.ps1")) {
      Copy-Item -LiteralPath (Join-Path $sourceDirectory $file) -Destination $scriptDirectory -Force
    }
    $script:provision = Join-Path $scriptDirectory "New-Workshop.ps1"
    $script:setup = @{
      SubscriptionId = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
      Location = "swedencentral"
      AdminCredential = [pscredential]::new("workshopadmin", (ConvertTo-SecureString 'Fx"7,$abCd' -AsPlainText -Force))
      OutputDirectory = Join-Path $TestDrive ("output-" + [guid]::NewGuid().ToString("N"))
    }
    $global:WorkshopTestState = @{
      Calls = [Collections.Generic.List[object]]::new()
      Deployments = [Collections.Generic.List[object]]::new()
      Mode = ""
    }
    function global:az {
      function Get-Argument($Name) {
        $position = [array]::IndexOf($a, $Name)
        if ($position -lt 0) { throw "Missing argument $Name" }
        $a[$position + 1]
      }
      $a = @($args)
      $state = $global:WorkshopTestState
      $state.Calls.Add($a)
      $global:LASTEXITCODE = 0
      $key = ($a | Select-Object -First 3) -join " "
      switch -Wildcard ($key) {
        "account show *" {
          @{ tenantId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"; id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" } | ConvertTo-Json
        }
        "group list *" {
          if ($state.Mode -eq "foreign-rg") {
            '[{"name":"rg-workshop-platform","location":"swedencentral","tags":{}}]'
          } elseif ($state.Mode -eq "retry") {
            '[{"name":"rg-workshop-platform","location":"swedencentral","tags":{"WorkshopId":"workshop","Purpose":"SingleWorkstation"}}]'
          } else { '[]' }
        }
        "bicep build *" {
          if (-not (Test-Path -LiteralPath (Get-Argument "--file") -PathType Leaf)) { throw "Bicep file was not resolved next to the script." }
          if ($state.Mode -eq "build-fails") { $global:LASTEXITCODE = 1 }
          else { Set-Content -LiteralPath (Get-Argument "--outfile") -Value "{}" }
        }
        "provider register *" { '{}' }
        "group create *" { '{}' }
        "deployment group create" {
          $file = (Get-Argument "--parameters").TrimStart("@")
          $values = (Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).parameters
          $state.Deployments.Add($values)
          if ($IsWindows) {
            $acl = Get-Acl -LiteralPath (Split-Path $file)
            if (-not $acl.AreAccessRulesProtected) { throw "Secrets directory inherits permissions." }
            $allowed = @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value, "S-1-5-18")
            foreach ($rule in $acl.Access) {
              if ($rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin $allowed) {
                throw "Secrets directory contains unexpected permissions."
              }
            }
          } else {
            $mode = (Get-Item -LiteralPath (Split-Path $file)).UnixMode
            if ($mode -ne 'drwx------') { throw "Secrets directory is not owner-only: $mode" }
          }
          if ($state.Mode -eq "deployment-fails" -and (Get-Argument "--name").EndsWith("-vm")) {
            $global:LASTEXITCODE = 9
            "Provider error with $($values.adminPassword.value)"
          } elseif ((Get-Argument "--name").EndsWith("-platform")) {
            @{
              properties = @{ outputs = @{
                subnetId = @{ value = "/test/subnets/desktops" }
                storageAccountName = @{ value = "stworkshoptest" }
                bastionName = @{ value = "workshop-bastion" }
              } }
            } | ConvertTo-Json -Depth 8
          } else {
            @{
              properties = @{ outputs = @{
                vmId = @{ value = "/test/vms/workshop-vm" }
                managedIdentityPrincipalId = @{ value = "dddddddd-dddd-dddd-dddd-dddddddddddd" }
                containerName = @{ value = "tfstate" }
              } }
            } | ConvertTo-Json -Depth 8
          }
        }
        "role assignment list" {
          if ($state.Mode -eq "retry") {
            '[{"scope":"/subscriptions/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","principalId":"dddddddd-dddd-dddd-dddd-dddddddddddd","roleDefinitionId":"/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"}]'
          } else { '[]' }
        }
        "role assignment create" {
          if ($state.Mode -eq "rbac-fails") { $global:LASTEXITCODE = 1; "Access denied" }
          else { '{}' }
        }
        default { throw "Unexpected Azure command: $key" }
      }
    }
  }
  AfterEach {
    Remove-Item Function:\global:az
    Remove-Variable WorkshopTestState -Scope Global
  }

  It "previews without any Azure calls or output files" {
    & $provision @setup -WhatIf
    $global:WorkshopTestState.Calls.Count | Should Be 0
    Test-Path $setup.OutputDirectory | Should Be $false
  }
  It "previews with the portable default when LOCALAPPDATA is absent" {
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
      Remove-Item Env:\LOCALAPPDATA -ErrorAction SilentlyContinue
      $setup.Remove("OutputDirectory")
      { & $provision @setup -WhatIf } | Should Not Throw
      $global:WorkshopTestState.Calls.Count | Should Be 0
    } finally { $env:LOCALAPPDATA = $previousLocalAppData }
  }
  It "deploys from a standalone sibling-file folder regardless of the working directory" {
    $standalone = Join-Path $TestDrive "standalone scripts"
    New-Item -ItemType Directory -Path $standalone | Out-Null
    foreach ($file in @("New-Workshop.ps1", "platform.bicep", "workstation.bicep", "bootstrap-windows.ps1")) {
      Copy-Item -LiteralPath (Join-Path $sourceDirectory $file) -Destination $standalone
    }
    Push-Location $TestDrive
    try {
      $result = & (Join-Path $standalone "New-Workshop.ps1") @setup -Confirm:$false
      $result.VmName | Should Be "workshop-vm"
      $global:WorkshopTestState.Deployments.Count | Should Be 2
    } finally { Pop-Location }
  }
  It "rejects missing sibling files before any Azure calls" {
    Remove-Item -LiteralPath (Join-Path (Split-Path $provision -Parent) "bootstrap-windows.ps1")
    { & $provision @setup -Confirm:$false } | Should Throw "Keep New-Workshop.ps1"
    $global:WorkshopTestState.Calls.Count | Should Be 0
    Test-Path $setup.OutputDirectory | Should Be $false
  }
  It "rejects output elsewhere inside the enclosing repository" {
    $setup.OutputDirectory = Join-Path $TestDrive "repository"
    { & $provision @setup -Confirm:$false } | Should Throw "outside the repository"
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "resolves an explicit relative output directory against the caller location" {
    Push-Location $TestDrive
    try {
      $setup.OutputDirectory = "relative-output"
      & $provision @setup -Confirm:$false | Out-Null
      @(Get-ChildItem -LiteralPath (Join-Path $TestDrive "relative-output") -Filter "access.json" -Recurse).Count | Should Be 1
    } finally { Pop-Location }
  }
  It "stops before writing files when Unix directory permissions cannot be restricted" -Skip:$IsWindows {
    $global:WorkshopTestState.Mode = "chmod-fails"
    Mock chmod { $global:LASTEXITCODE = 1 } -ParameterFilter { $global:WorkshopTestState.Mode -eq "chmod-fails" }
    { & $provision @setup -Confirm:$false } | Should Throw "Cannot restrict permissions"
    $global:WorkshopTestState.Deployments.Count | Should Be 0
    @(Get-ChildItem $setup.OutputDirectory -Recurse -File).Count | Should Be 0
  }
  It "accepts mixed-case local administrator names without a second credential" {
    $setup.AdminCredential = [pscredential]::new("Workshop-Admin_01", $setup.AdminCredential.Password)
    { & $provision @setup -WhatIf } | Should Not Throw
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "rejects weak credentials offline" {
    $setup.AdminCredential = [pscredential]::new("workshopadmin", (ConvertTo-SecureString "weak" -AsPlainText -Force))
    { & $provision @setup -WhatIf } | Should Throw "at least 8"
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "rejects reserved administrator usernames offline with actionable guidance" {
    foreach ($name in @("admin", "Administrator", "USER", "guest", "defaultaccount")) {
      $setup.AdminCredential = [pscredential]::new($name, $setup.AdminCredential.Password)
      { & $provision @setup -WhatIf } | Should Throw "reserved"
    }
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "accepts passwords with only the four requested requirements and no maximum length" {
    foreach ($password in @('Abcde7!x', 'Abcdef7!x', 'Abcdefg7!x', 'ABCDEFG7!X', 'Abcdefgh7!x', ('Abc7!' + ('x' * 124)), 'REPLACE_WITH7!', "Abcde7!`n")) {
      $setup.AdminCredential = [pscredential]::new("workshopadmin", (ConvertTo-SecureString $password -AsPlainText -Force))
      { & $provision @setup -WhatIf } | Should Not Throw
    }
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "explains each failed password check without exposing the password" {
    $cases = @(
      @{ Password = 'Abcd7!x'; Reason = 'too short' }
      @{ Password = 'abcdef7!x'; Reason = 'missing an uppercase letter' }
      @{ Password = 'Abcdefg!x'; Reason = 'missing a number' }
      @{ Password = 'Abcdefg7x'; Reason = 'missing a special character' }
    )
    foreach ($case in $cases) {
      $setup.AdminCredential = [pscredential]::new("workshopadmin", (ConvertTo-SecureString $case.Password -AsPlainText -Force))
      $message = ""
      try { & $provision @setup -WhatIf } catch { $message = $_.Exception.Message }
      $message | Should Match ([regex]::Escape($case.Reason))
      $message | Should Match 'Get-Credential'
      $message | Should Not Match ([regex]::Escape($case.Password))
    }
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "reports all failed password checks together" {
    $setup.AdminCredential = [pscredential]::new("workshopadmin", (ConvertTo-SecureString 'weak' -AsPlainText -Force))
    $message = ""
    try { & $provision @setup -WhatIf } catch { $message = $_.Exception.Message }
    foreach ($reason in @('too short', 'missing an uppercase letter', 'missing a number', 'missing a special character')) {
      $message | Should Match $reason
    }
    $message | Should Not Match 'weak'
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "does not add a local username restriction to the four password requirements" {
    $setup.AdminCredential = [pscredential]::new("operator", (ConvertTo-SecureString 'Operator7!' -AsPlainText -Force))
    { & $provision @setup -WhatIf } | Should Not Throw
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "rejects email and domain credentials instead of treating them as local accounts" {
    foreach ($name in @("someone@example.com", "DOMAIN\person", ".\workshopadmin", "name with spaces", "workshopadmin`n")) {
      $setup.AdminCredential = [pscredential]::new($name, $setup.AdminCredential.Password)
      { & $provision @setup -WhatIf } | Should Throw "local Windows username"
    }
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "accepts twenty-character usernames and rejects longer names" {
    $setup.AdminCredential = [pscredential]::new("WorkshopOperator1234", $setup.AdminCredential.Password)
    { & $provision @setup -WhatIf } | Should Not Throw
    $setup.AdminCredential = [pscredential]::new(("W" * 20), $setup.AdminCredential.Password)
    { & $provision @setup -WhatIf } | Should Not Throw
    $setup.AdminCredential = [pscredential]::new(("W" * 21), $setup.AdminCredential.Password)
    { & $provision @setup -WhatIf } | Should Throw "1-20"
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "rejects unsupported Terraform versions offline" {
    $setup.TerraformVersion = "2.0.0"
    { & $provision @setup -WhatIf } | Should Throw "newer 1.x"
    $global:WorkshopTestState.Calls.Count | Should Be 0
  }
  It "does not write credential files into the repository" {
    $setup.OutputDirectory = Join-Path (Split-Path $provision -Parent) "output"
    { & $provision @setup -Confirm:$false } | Should Throw "outside the repository"
    Test-Path $setup.OutputDirectory | Should Be $false
    $global:WorkshopTestState.Deployments.Count | Should Be 0
  }
  It "creates only one platform RG and one VM with MI subscription Contributor" {
    $result = & $provision @setup -Confirm:$false
    $state = $global:WorkshopTestState
    $state.Deployments.Count | Should Be 2
    @($state.Calls | Where-Object { $_[0] -eq "group" -and $_[1] -eq "create" }).Count | Should Be 1
    $state.Deployments[1].vmName.value | Should Be "workshop-vm"
    $state.Deployments[1].adminUsername.value | Should Be "workshopadmin"
    $state.Deployments[1].adminPassword.value | Should Be $setup.AdminCredential.GetNetworkCredential().Password
    ($state.Deployments[1].PSObject.Properties.Name -contains "vmPassword") | Should Be $false
    ($state.Deployments[1].PSObject.Properties.Name -contains "vmUsername") | Should Be $false
    $result.VmUsername | Should Be $setup.AdminCredential.UserName
    $assignment = @($state.Calls | Where-Object { $_[0] -eq "role" -and $_[2] -eq "create" })
    $assignment.Count | Should Be 1
    ($assignment[0] -join " ") | Should Match '--assignee-principal-type ServicePrincipal'
    ($assignment[0] -join " ") | Should Match '--scope /subscriptions/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb '
    ($assignment[0] -join " ") | Should Match 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    $result.ManagedIdentityPrincipalId | Should Be "dddddddd-dddd-dddd-dddd-dddddddddddd"
    $result.TenantId | Should Be "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    $result.ContainerName | Should Be "tfstate"
    $result.BackendKey | Should Be "lab05.tfstate"
    $files = @(Get-ChildItem $setup.OutputDirectory -Recurse -File)
    $files.Count | Should Be 1
    $files[0].Name | Should Be "access.json"
    (Get-Content $files[0].FullName -Raw) | Should Not Match ([regex]::Escape($setup.AdminCredential.GetNetworkCredential().Password))
    ($state.Calls | ConvertTo-Json -Depth 10) | Should Not Match "graph.microsoft.com|--member-id"
    ($state.Calls | ForEach-Object { $_ -join " " }) -join "`n" | Should Not Match ([regex]::Escape($setup.AdminCredential.GetNetworkCredential().Password))
  }

  It "retries without duplicate RGs or subscription role assignments" {
    $global:WorkshopTestState.Mode = "retry"
    & $provision @setup -Confirm:$false | Out-Null
    @($global:WorkshopTestState.Calls | Where-Object { $_[0] -in @("group", "role") -and $_ -contains "create" }).Count | Should Be 0
  }
  It "rejects foreign or legacy resource groups" {
    $global:WorkshopTestState.Mode = "foreign-rg"
    { & $provision @setup -Confirm:$false } | Should Throw "Existing resource group"
    $global:WorkshopTestState.Deployments.Count | Should Be 0
  }
  It "stops before resource writes when Bicep compilation fails" {
    $global:WorkshopTestState.Mode = "build-fails"
    { & $provision @setup -Confirm:$false } | Should Throw "Bicep compilation failed"
    @($global:WorkshopTestState.Calls | Where-Object { $_[0] -in @("provider", "deployment", "role") }).Count | Should Be 0
    @(Get-ChildItem $setup.OutputDirectory -Recurse -File).Count | Should Be 0
  }
  It "sanitizes deployment failures and removes private parameters and generated templates" {
    $global:WorkshopTestState.Mode = "deployment-fails"
    $message = ""
    try { & $provision @setup -Confirm:$false } catch { $message = $_.Exception.Message }
    $message | Should Match "exit 9"
    $message | Should Not Match ([regex]::Escape($setup.AdminCredential.GetNetworkCredential().Password))
    $global:WorkshopTestState.Deployments[1].adminPassword.value | Should Be $setup.AdminCredential.GetNetworkCredential().Password
    @(Get-ChildItem $setup.OutputDirectory -Recurse -File).Count | Should Be 0
  }
  It "does not report success if subscription role assignment fails" {
    $global:WorkshopTestState.Mode = "rbac-fails"
    { & $provision @setup -Confirm:$false } | Should Throw "exit 1"
    @(Get-ChildItem $setup.OutputDirectory -Recurse -File).Count | Should Be 0
  }
}

Describe "Bootstrap installer validation (offline)" {
  BeforeEach {
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $sourceDirectory "bootstrap-windows.ps1"), [ref]$tokens, [ref]$parseErrors)
    $functions = $ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -in @("Invoke-Installer", "Assert-ValidSignature")
    }, $true)
    foreach ($function in $functions) { . ([scriptblock]::Create($function.Extent.Text)) }
  }
  It "accepts installer success and reboot-required exit codes" {
    Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
    { Invoke-Installer -FilePath "fixture.exe" -ArgumentList "/quiet" } | Should Not Throw
    Mock Start-Process { [pscustomobject]@{ ExitCode = 3010 } }
    { Invoke-Installer -FilePath "fixture.exe" -ArgumentList "/quiet" } | Should Not Throw
  }
  It "rejects installer failure exit codes" {
    Mock Start-Process { [pscustomobject]@{ ExitCode = 1603 } }
    { Invoke-Installer -FilePath "fixture.exe" -ArgumentList "/quiet" } | Should Throw "1603"
  }
  It "rejects invalid installer signatures" -Skip:(-not $IsWindows) {
    Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = "NotSigned"; StatusMessage = "Not signed" } }
    { Assert-ValidSignature -FilePath "fixture.exe" } | Should Throw "valid Authenticode"
  }
  It "accepts valid installer signatures" -Skip:(-not $IsWindows) {
    Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = "Valid"; StatusMessage = "Valid signature" } }
    { Assert-ValidSignature -FilePath "fixture.exe" } | Should Not Throw
  }
}

Describe "Infrastructure and bootstrap contracts (offline)" {
  It "has one private system-assigned VM, protected credentials and container-scoped data access" {
    $template = Get-Content (Join-Path $sourceDirectory "workstation.bicep") -Raw
    $template | Should Match "identity: \{ type: 'SystemAssigned' \}"
    $template | Should Match "scope: container"
    $template | Should Match "principalId: vm.identity.principalId"
    $template | Should Match "principalType: 'ServicePrincipal'"
    $template | Should Match "@secure\(\)\s+param adminPassword string"
    $template | Should Match "name: 'VmUsername', value: adminUsername"
    $template | Should Not Match "Learner|vmPassword|protectedParameters"
    $template | Should Match "treatFailureAsDeploymentFailure: true"
    $template | Should Match "loadTextContent\('bootstrap-windows.ps1'\)"
    $template | Should Not Match "guestObjectId|attendeeId|publicIPAddress"
    $platform = Get-Content (Join-Path $sourceDirectory "platform.bicep") -Raw
    $platform | Should Match "RdpFromBastion"
    $platform | Should Match "DenyOtherInbound"
    $platform | Should Match "allowSharedKeyAccess: false"
    $platform | Should Match "defaultAction: 'Deny'"
    $platform | Should Not Match "cohortGroupId|groupReader"
  }
  It "generates parseable administrator auth and tool verification scripts without running SYSTEM login" {
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $sourceDirectory "bootstrap-windows.ps1"), [ref]$tokens, [ref]$parseErrors)
    @($parseErrors).Count | Should Be 0
    $assignments = $ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left.Extent.Text -in @('$authenticationScript', '$verificationScript')
    }, $true)
    $assignments.Count | Should Be 2
    foreach ($assignment in $assignments) {
      $text = $assignment.Right.Expression.Value
      [Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$parseErrors) | Out-Null
      @($parseErrors).Count | Should Be 0
    }
    $bootstrap = Get-Content (Join-Path $sourceDirectory "bootstrap-windows.ps1") -Raw
    $bootstrap | Should Match 'az login --identity --allow-no-subscriptions --output none'
    $bootstrap | Should Match 'Connect-WorkshopAzure\.ps1'
    $bootstrap | Should Match 'ARM_USE_MSI = "true"'
    $bootstrap | Should Match 'ARM_USE_CLI = "false"'
    $bootstrap | Should Match 'ARM_USE_AZUREAD = "true"'
    $bootstrap | Should Match 'ARM_SUBSCRIPTION_ID'
    $bootstrap | Should Match 'ARM_TENANT_ID'
    $bootstrap | Should Match 'S-1-5-18'
    $bootstrap | Should Match 'S-1-5-32-544'
    $bootstrap | Should Match 'Get-AuthenticodeSignature'
    $bootstrap | Should Match 'Get-FileHash.*SHA256'
    $bootstrap | Should Match 'ExitCode -notin @\(0, 3010\)'
    $bootstrap | Should Match 'exit 1'
    $bootstrap | Should Not Match 'az login --tenant|--password'
    $bootstrap | Should Not Match 'Learner|New-LocalUser|Set-LocalUser|ConvertTo-SecureString'
    $bootstrap | Should Match 'Get-LocalUser -Name \$VmUsername'
  }
}
