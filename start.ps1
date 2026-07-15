# start.ps1 — Start BPMN IQ 2.0 (Server + Client)
$ErrorActionPreference = "Stop"

Write-Host "=== BPMN IQ 2.0 Startup ===" -ForegroundColor Cyan

# 1. MongoDB: using a remote cluster (MONGO_URI in server/.env), so no local
#    Mongo service/port check is needed here.
Write-Host "[OK] Using MongoDB connection from server/.env (MONGO_URI)." -ForegroundColor Green

# 2. Clear NODE_OPTIONS (Dynatrace workaround)
$env:NODE_OPTIONS = ""

function Stop-ProcessOnPort {
	param(
		[Parameter(Mandatory = $true)]
		[int] $Port,

		[Parameter(Mandatory = $true)]
		[string] $Name
	)

	$processIds = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
		Select-Object -ExpandProperty OwningProcess -Unique

	if (-not $processIds) {
		Write-Host "[OK] No existing $Name process found on port $Port." -ForegroundColor Green
		return
	}

	foreach ($processId in $processIds) {
		try {
			Stop-Process -Id $processId -Force -ErrorAction Stop
			Write-Host "[OK] Stopped existing $Name process (PID $processId) on port $Port." -ForegroundColor Yellow
		}
		catch {
			Write-Host "[WARN] Could not stop $Name process (PID $processId) on port $Port: $($_.Exception.Message)" -ForegroundColor Yellow
		}
	}
}

# 3. Ensure dependencies are installed before starting the local binaries.
function Ensure-YarnInstall {
	param(
		[Parameter(Mandatory = $true)]
		[string] $WorkingDirectory
	)

	$nodeModulesPath = Join-Path $WorkingDirectory "node_modules"
	if (-not (Test-Path $nodeModulesPath)) {
		Write-Host "[*] Installing dependencies in $WorkingDirectory..." -ForegroundColor Yellow
		Push-Location $WorkingDirectory
		try {
			& cmd.exe /c yarn.cmd install
		}
		finally {
			Pop-Location
		}
	}
}

Ensure-YarnInstall -WorkingDirectory $PSScriptRoot
Ensure-YarnInstall -WorkingDirectory (Join-Path $PSScriptRoot "server")
Ensure-YarnInstall -WorkingDirectory (Join-Path $PSScriptRoot "client")

# 4. Start server + client
Write-Host "[*] Starting Express server + Vite client..." -ForegroundColor Yellow

Stop-ProcessOnPort -Port 3001 -Name "Express server"
Stop-ProcessOnPort -Port 5173 -Name "Vite client"

function Start-BackgroundYarnDev {
	param(
		[Parameter(Mandatory = $true)]
		[string] $WorkingDirectory,

		[Parameter(Mandatory = $true)]
		[string] $Name
	)

	Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "yarn.cmd", "dev") -WorkingDirectory $WorkingDirectory -WindowStyle Hidden
	Write-Host "[OK] Started $Name dev server in $WorkingDirectory" -ForegroundColor Green
}

Start-BackgroundYarnDev -WorkingDirectory (Join-Path $PSScriptRoot "server") -Name "Express server"
Start-BackgroundYarnDev -WorkingDirectory (Join-Path $PSScriptRoot "client") -Name "Vite client"

Write-Host "[*] Dev servers launched. Keep this terminal open if you want to monitor startup logs." -ForegroundColor Cyan
