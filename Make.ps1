# Load environment variables from .env
if (Test-Path .env) {
    Get-Content .env | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
        $name, $value = $_.Split('=', 2)
        [System.Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim())
    }
}

function Run-Up {
    $frontendCfg = "./haproxy/haproxy-frontend.cfg"
    $exampleCfg = "./haproxy/haproxy-frontend.cfg.example"
    if (-not (Test-Path $frontendCfg) -and (Test-Path $exampleCfg)) {
        Copy-Item $exampleCfg $frontendCfg
    }
    docker compose up -d
}

function Run-Down {
    docker compose down -v
}

# --- Dev Database ---
function Run-DevBackup {
    Write-Host "Dumping remote database..." -ForegroundColor Cyan
    $cmd = "PGPASSWORD=$env:REMOTE_DB_PASS pg_dump -Fc -v -d $env:REMOTE_DB_DATABASE -h $env:REMOTE_DB_HOST -U $env:REMOTE_DB_USER > /tmp/db_backup.gz"
    Measure-Command { docker compose exec db_dev bash -c $cmd } | Out-Default
    Write-Host "Finished database dump from dev" -ForegroundColor Green
}

function Run-DevRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_dev
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_dev bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_dev bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/db_backup.gz"
    Measure-Command { docker compose exec db_dev bash -c $cmd } | Out-Default
    Write-Host "Finished restoring local database from dev backup" -ForegroundColor Green
    Add-Content -Path "restore.log" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') dev_restore"
}

# --- QA Database ---
function Run-QaBackup {
    Write-Host "Dumping remote QA database..." -ForegroundColor Cyan
    $cmd = "PGPASSWORD=$env:QA_DB_PASS pg_dump -Fc -v -d $env:QA_DB_DATABASE -h $env:QA_DB_HOST -U $env:QA_DB_USER --exclude-table-data=printer_server_errors > /tmp/qa_db_backup.gz"
    Measure-Command { docker compose exec db_qa bash -c $cmd } | Out-Default
    Write-Host "Finished remote QA database dump" -ForegroundColor Green
}

function Run-QaRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_qa
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_qa bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_qa bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/qa_db_backup.gz"
    Measure-Command { docker compose exec db_qa bash -c $cmd } | Out-Default
    Write-Host "Finished restoring local database from QA backup" -ForegroundColor Green
    Add-Content -Path "restore.log" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') qa_restore"
}

# --- Snap Database ---
function Run-SnapBackup {
    Write-Host "Dumping remote Snap database..." -ForegroundColor Cyan
    $cmd = "PGPASSWORD=$env:SNAP_DB_PASS pg_dump -Fc -v -d $env:SNAP_DB_DATABASE -h $env:SNAP_DB_HOST -U $env:SNAP_DB_USER --exclude-table-data=printer_server_errors > /tmp/snap_db_backup.gz"
    Measure-Command { docker compose exec db_snap bash -c $cmd } | Out-Default
    Write-Host "Finished remote Snap database dump" -ForegroundColor Green
}

function Run-SnapRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_snap
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_snap bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"

    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_snap bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"

    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/snap_db_backup.gz"
    Measure-Command { docker compose exec db_snap bash -c $cmd } | Out-Default
    Write-Host "Finished restoring local database from Snap backup" -ForegroundColor Green
    Add-Content -Path "restore.log" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') snap_restore"
}

# --- Prod Database ---
function Run-ProdBackup {
    Write-Host "Starting production database backup..." -ForegroundColor Cyan
    # Shell scripts inside containers still need execution rights
    docker compose exec db_prod bash -c "chmod +x /tmp/prod_backup.sh && /tmp/prod_backup.sh"
    Write-Host "Production database backup completed" -ForegroundColor Green
}

function Run-ProdRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_prod
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_prod bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_prod bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/prod_backup.dump"
    Measure-Command { docker compose exec db_prod bash -c $cmd } | Out-Default
    Write-Host "Finished restoring local database from prod backup" -ForegroundColor Green
    Add-Content -Path "restore.log" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') prod_restore"
}

# --- Proxy Management (writes gitignored haproxy-frontend.cfg only) ---
function Update-Haproxy {
    param($backend)
    Write-Host "Activating $backend database..." -ForegroundColor Cyan
    $frontendCfg = "./haproxy/haproxy-frontend.cfg"
    @"
frontend pg-frontend
    bind *:5432
    default_backend $backend
"@ | Set-Content -Path $frontendCfg -NoNewline
    docker compose restart db-proxy
    Write-Host "$backend database activated" -ForegroundColor Green
}

function Show-RestoreLog {
    $logFile = "restore.log"
    if (Test-Path $logFile) {
        Write-Host ""
        Write-Host "Last Restore Times"
        Write-Host ""
        Write-Host ("  {0,-8} {1,-19} {2}" -f "Env", "Elapsed", "Date")
        Write-Host ("  {0,-8} {1,-19} {2}" -f "---", "-------", "-------------------")
        foreach ($db in @("dev_restore", "qa_restore", "snap_restore", "prod_restore")) {
            $last = Get-Content $logFile | Where-Object { $_ -match " $db$" } | Select-Object -Last 1
            $envName = $db -replace '_restore', ''
            if ($last) {
                $ts = ($last -split '\s+', 3)[0..1] -join ' '
                $parsed = [datetime]::ParseExact($ts, 'yyyy-MM-dd HH:mm:ss', $null)
                $tsFmt = $parsed.ToString('yyyy/MM/dd HH:mm:ss')
                $diff = (Get-Date) - $parsed
                if ($diff.TotalMinutes -lt 1) {
                    $elapsed = "$([math]::Floor($diff.TotalSeconds)) seconds ago"
                } elseif ($diff.TotalHours -lt 1) {
                    $elapsed = "$([math]::Floor($diff.TotalMinutes)) minutes ago"
                } elseif ($diff.TotalDays -lt 1) {
                    $elapsed = "$([math]::Floor($diff.TotalHours)) hours ago"
                } else {
                    $elapsed = "$([math]::Floor($diff.TotalDays)) days ago"
                }
            } else {
                $elapsed = "never"
                $tsFmt = [string][char]0x2014
            }
            Write-Host ("  {0,-8} {1,-19} {2}" -f $envName, $elapsed, $tsFmt)
        }
        Write-Host ""
    } else {
        Write-Host "No restores logged yet ($logFile not found)."
    }
}

# --- Command Router ---
switch ($args[0]) {
    "up"             { Run-Up }
    "down"           { Run-Down }
    "dev_backup"     { Run-DevBackup }
    "dev_restore"    { Run-DevRestore }
    "dev_refresh"    { Run-DevBackup; Run-DevRestore }
    "qa_backup"      { Run-QaBackup }
    "qa_restore"     { Run-QaRestore }
    "qa_refresh"     { Run-QaBackup; Run-QaRestore }
    "snap_backup"    { Run-SnapBackup }
    "snap_restore"   { Run-SnapRestore }
    "snap_refresh"   { Run-SnapBackup; Run-SnapRestore }
    "prod_backup"    { Run-ProdBackup }
    "prod_restore"   { Run-ProdRestore }
    "prod_refresh"   { Run-ProdBackup; Run-ProdRestore }
    "activate_dev"   { Update-Haproxy "dev-db" }
    "activate_qa"    { Update-Haproxy "qa-db" }
    "activate_snap"  { Update-Haproxy "snap-db" }
    "activate_prod"  { Update-Haproxy "prod-db" }
    "show_restore_log" { Show-RestoreLog }
    "show_active_env" {
        $cfgPath = "./haproxy/haproxy-frontend.cfg"
        $envName = "unknown"
        if (Test-Path $cfgPath) {
            $line = Get-Content $cfgPath | Where-Object { $_ -match 'default_backend\s+(\S+)' } | Select-Object -First 1
            if ($line -match 'default_backend\s+(\w+)-') { $envName = $Matches[1] }
        }
        Write-Host "Current environment is: $envName"
    }
    default {
        Write-Host "Usage: .\Makefile.ps1 [up|down|dev_refresh|qa_refresh|prod_refresh|activate_dev|...]" -ForegroundColor Gray
    }
}
