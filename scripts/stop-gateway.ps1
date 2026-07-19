param(
  [string]$StateRoot = "$HOME\.codex-retry-gateway",
  [switch]$Quiet,
  [switch]$SkipRestore
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-GatewayStatePaths -StateRoot $StateRoot
$state = Read-JsonFile -Path $paths.StatePath
$backupPath = ""
$codexConfigPath = "$HOME\.codex\config.toml"
if (-not $SkipRestore -and $null -ne $state) {
  $backupProperty = $state.PSObject.Properties["latest_backup_path"]
  if ($null -ne $backupProperty -and -not [string]::IsNullOrWhiteSpace([string]$backupProperty.Value)) {
    $backupPath = [string]$backupProperty.Value
    if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
      throw "A restorable backup file was not found: $backupPath"
    }
    $codexConfigPathProperty = $state.PSObject.Properties["codex_config_path"]
    if ($null -ne $codexConfigPathProperty -and -not [string]::IsNullOrWhiteSpace([string]$codexConfigPathProperty.Value)) {
      $codexConfigPath = [string]$codexConfigPathProperty.Value
    }
  }
}

$message = ""
if (-not (Test-Path -LiteralPath $paths.PidPath)) {
  $message = "No running gateway PID file was found."
} else {
  $pidRaw = (Get-Content -LiteralPath $paths.PidPath -Raw).Trim()
  if (-not $pidRaw) {
    Remove-Item -LiteralPath $paths.PidPath -Force
    $message = "Gateway PID file was empty and has been removed."
  } else {
    $gatewayPid = [int]$pidRaw
    if (Test-ProcessAlive -ProcessId $gatewayPid) {
      $gatewayConfig = Read-JsonFile -Path $paths.ConfigPath
      if ($null -eq $gatewayConfig) {
        $gatewayBaseUrlProperty = if ($state) { $state.PSObject.Properties["gateway_base_url"] } else { $null }
        if (
          $null -ne $gatewayBaseUrlProperty -and
          -not [string]::IsNullOrWhiteSpace([string]$gatewayBaseUrlProperty.Value)
        ) {
          $gatewayConfig = Get-GatewayRuntimeConfig `
            -GatewayBaseUrl ([string]$gatewayBaseUrlProperty.Value) `
            -ProcessId $gatewayPid
        }
      }
      if ($null -eq $gatewayConfig -or -not (Test-GatewayProcessIdentity -ProcessId $gatewayPid -GatewayConfig $gatewayConfig)) {
        throw "Gateway PID could not be verified and was not stopped: $gatewayPid"
      }
      Stop-Process -Id $gatewayPid -Force
    }

    Remove-Item -LiteralPath $paths.PidPath -Force -ErrorAction SilentlyContinue
    $message = "Gateway stopped. PID=$gatewayPid"
  }
}

if (-not [string]::IsNullOrWhiteSpace($backupPath)) {
  Copy-Item -LiteralPath $backupPath -Destination $codexConfigPath -Force
  Remove-Item -LiteralPath $paths.StatePath -Force -ErrorAction SilentlyContinue
  $message = "$message Codex config restored from $backupPath."
}

if (-not $Quiet) {
  Write-Output $message
}
