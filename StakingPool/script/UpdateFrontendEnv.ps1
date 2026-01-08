param(
    [string]$RpcUrl = "http://127.0.0.1:8545",
    [string]$PrivateKey = ""
)

$ErrorActionPreference = "Stop"

function Read-EnvFile($path) {
    $map = @{}
    if (Test-Path $path) {
        Get-Content $path | ForEach-Object {
            if ($_ -match "^\s*#") { return }
            if ($_ -match "^\s*$") { return }
            $parts = $_.Split("=", 2)
            if ($parts.Length -eq 2) {
                $map[$parts[0].Trim()] = $parts[1].Trim()
            }
        }
    }
    return $map
}

$root = Split-Path -Parent $PSScriptRoot
$frontendEnv = Join-Path $root "frontend\.env.local"

$env:DEPLOY_MOCKS = "true"

$cmd = "forge script script/Deploy.s.sol --rpc-url $RpcUrl --broadcast -vvvv"
if ($PrivateKey -and $PrivateKey.Length -gt 0) {
    $cmd = "$cmd --private-key $PrivateKey"
}

Write-Host "Running: $cmd"
$raw = Invoke-Expression $cmd | Out-String

$stakingPool = ($raw | Select-String -Pattern "StakingPool:\s*(0x[a-fA-F0-9]{40})" | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -First 1
$zzToken = ($raw | Select-String -Pattern "ZZToken:\s*(0x[a-fA-F0-9]{40})" | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -First 1
$aToken = ($raw | Select-String -Pattern "Mock aToken:\s*(0x[a-fA-F0-9]{40})" | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -First 1
$weth = ($raw | Select-String -Pattern "WETH:\s*(0x[a-fA-F0-9]{40})" | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -First 1
$lendingPool = ($raw | Select-String -Pattern "LendingPool:\s*(0x[a-fA-F0-9]{40})" | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -First 1

if (-not $stakingPool) { throw "Failed to parse StakingPool address." }
if (-not $zzToken) { throw "Failed to parse ZZToken address." }
if (-not $aToken) { throw "Failed to parse Mock aToken address." }
if (-not $weth) { throw "Failed to parse WETH address." }
if (-not $lendingPool) { throw "Failed to parse LendingPool address." }

$existing = Read-EnvFile $frontendEnv
$walletConnect = $existing["NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID"]

$lines = @()
if ($walletConnect) {
    $lines += "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=$walletConnect"
} else {
    $lines += "# NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id"
}
$lines += "NEXT_PUBLIC_STAKING_POOL_ADDRESS=$stakingPool"
$lines += "NEXT_PUBLIC_ZZ_TOKEN_ADDRESS=$zzToken"
$lines += "NEXT_PUBLIC_A_TOKEN_ADDRESS=$aToken"
$lines += "NEXT_PUBLIC_LENDING_POOL_ADDRESS=$lendingPool"
$lines += "NEXT_PUBLIC_WETH_ADDRESS=$weth"

$lines | Set-Content -Path $frontendEnv -Encoding ASCII

Write-Host "Updated $frontendEnv"
Write-Host "StakingPool: $stakingPool"
Write-Host "ZZToken: $zzToken"
Write-Host "Mock aToken: $aToken"
Write-Host "LendingPool: $lendingPool"
Write-Host "WETH: $weth"
