# Load environment variables from .env
if (Test-Path .env) {
    Get-Content .env | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
        $name, $value = $_.Split('=', 2)
        [System.Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim())
    }
}

$LogFile = "restore.log"

function Add-LogEntry {
    param([string]$LogEvent)
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $LogEvent"
}

# docker compose failures do not stop the script, so success has to be checked
# explicitly before anything is written to the log.
function Assert-LastExitOk {
    param([string]$What)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$What failed (exit $LASTEXITCODE); nothing logged" -ForegroundColor Red
        exit 1
    }
}

# docker compose restart returns as soon as the container is up, before postgres has
# finished WAL recovery, so dropdb would race the server and fail on a missing socket.
function Wait-ForDb {
    param([string]$Service)
    Write-Host "Waiting for $Service to accept connections..." -ForegroundColor Cyan
    for ($i = 1; $i -le 300; $i++) {
        docker compose exec -T $Service pg_isready -q -U $env:LOCAL_DB_USER 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 1
    }
    Write-Host "Timed out waiting for $Service to accept connections" -ForegroundColor Red
    exit 1
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
    $cmd = "PGPASSWORD=$env:REMOTE_DB_PASS pg_dump -Fc -v -d $env:REMOTE_DB_DATABASE -h $env:REMOTE_DB_HOST -U $env:REMOTE_DB_USER -n public > /tmp/db_backup.gz"
    Measure-Command { docker compose exec db_dev bash -c $cmd } | Out-Default
    Assert-LastExitOk "Dev backup"
    Write-Host "Finished database dump from dev" -ForegroundColor Green
    Add-LogEntry "dev_backup"
}

function Run-DevRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_dev
    Wait-ForDb "db_dev"
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_dev bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_dev bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/db_backup.gz"
    Measure-Command { docker compose exec db_dev bash -c $cmd } | Out-Default
    Assert-LastExitOk "Dev restore"
    Write-Host "Finished restoring local database from dev backup" -ForegroundColor Green
    Add-LogEntry "dev_restore"
}

# --- QA Database ---
function Run-QaBackup {
    Write-Host "Dumping remote QA database..." -ForegroundColor Cyan
    $cmd = "PGPASSWORD=$env:QA_DB_PASS pg_dump -Fc -v -d $env:QA_DB_DATABASE -h $env:QA_DB_HOST -U $env:QA_DB_USER -n public --exclude-table-data=printer_server_errors > /tmp/qa_db_backup.gz"
    Measure-Command { docker compose exec db_qa bash -c $cmd } | Out-Default
    Assert-LastExitOk "QA backup"
    Write-Host "Finished remote QA database dump" -ForegroundColor Green
    Add-LogEntry "qa_backup"
}

function Run-QaRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_qa
    Wait-ForDb "db_qa"
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_qa bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_qa bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/qa_db_backup.gz"
    Measure-Command { docker compose exec db_qa bash -c $cmd } | Out-Default
    Assert-LastExitOk "QA restore"
    Write-Host "Finished restoring local database from QA backup" -ForegroundColor Green
    Add-LogEntry "qa_restore"
}

# --- Snap Database ---
function Run-SnapBackup {
    Write-Host "Dumping remote Snap database..." -ForegroundColor Cyan
    $cmd = "PGPASSWORD=$env:SNAP_DB_PASS pg_dump -Fc -v -d $env:SNAP_DB_DATABASE -h $env:SNAP_DB_HOST -U $env:SNAP_DB_USER -n public --exclude-table-data=printer_server_errors > /tmp/snap_db_backup.gz"
    Measure-Command { docker compose exec db_snap bash -c $cmd } | Out-Default
    Assert-LastExitOk "Snap backup"
    Write-Host "Finished remote Snap database dump" -ForegroundColor Green
    Add-LogEntry "snap_backup"
}

function Run-SnapRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_snap
    Wait-ForDb "db_snap"
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_snap bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"

    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_snap bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"

    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/snap_db_backup.gz"
    Measure-Command { docker compose exec db_snap bash -c $cmd } | Out-Default
    Assert-LastExitOk "Snap restore"
    Write-Host "Finished restoring local database from Snap backup" -ForegroundColor Green
    Add-LogEntry "snap_restore"
}

# --- Prod Database ---
function Run-ProdBackup {
    Write-Host "Starting production database backup..." -ForegroundColor Cyan
    # Shell scripts inside containers still need execution rights
    docker compose exec db_prod bash -c "chmod +x /tmp/prod_backup.sh && /tmp/prod_backup.sh"
    Assert-LastExitOk "Prod backup"
    Write-Host "Production database backup completed" -ForegroundColor Green
    Add-LogEntry "prod_backup"
}

function Run-ProdRestore {
    Write-Host "Restarting database container to ensure no active connections..." -ForegroundColor Cyan
    docker compose restart db_prod
    Wait-ForDb "db_prod"
    Write-Host "Dropping local database..." -ForegroundColor Yellow
    docker compose exec db_prod bash -c "PGPASSWORD=$env:LOCAL_DB_PASS dropdb --if-exists -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Creating local database..." -ForegroundColor Yellow
    docker compose exec db_prod bash -c "PGPASSWORD=$env:LOCAL_DB_PASS createdb -U $env:LOCAL_DB_USER $env:LOCAL_DB_DATABASE"
    
    Write-Host "Restoring local database..." -ForegroundColor Yellow
    $cmd = "PGPASSWORD=$env:LOCAL_DB_PASS pg_restore --clean --if-exists -Fc -U $env:LOCAL_DB_USER -d $env:LOCAL_DB_DATABASE /tmp/prod_backup.dump"
    Measure-Command { docker compose exec db_prod bash -c $cmd } | Out-Default
    Assert-LastExitOk "Prod restore"
    Write-Host "Finished restoring local database from prod backup" -ForegroundColor Green
    Add-LogEntry "prod_restore"
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

$RowFormat = "  {0,-8} {1,-15} {2,-21} {3,-15} {4}"

function Get-LastLogTimestamp {
    param([string]$EnvName, [string]$Kind)
    # A historical "<env>_refresh" line counts as both a backup and a restore.
    $last = Get-Content $LogFile | Where-Object { $_ -match " $EnvName`_($Kind|refresh)$" } | Select-Object -Last 1
    if (-not $last) { return $null }
    $ts = ($last -split '\s+', 3)[0..1] -join ' '
    return [datetime]::ParseExact($ts, 'yyyy-MM-dd HH:mm:ss', $null)
}

function Format-Elapsed {
    param([nullable[datetime]]$Stamp)
    if ($null -eq $Stamp) { return "never" }
    $diff = (Get-Date) - $Stamp
    if ($diff.TotalMinutes -lt 1) {
        return "$([math]::Floor($diff.TotalSeconds)) seconds ago"
    } elseif ($diff.TotalHours -lt 1) {
        return "$([math]::Floor($diff.TotalMinutes)) minutes ago"
    } elseif ($diff.TotalDays -lt 1) {
        return "$([math]::Floor($diff.TotalHours)) hours ago"
    } else {
        return "$([math]::Floor($diff.TotalDays)) days ago"
    }
}

function Format-LogDate {
    param([nullable[datetime]]$Stamp)
    if ($null -eq $Stamp) { return "-" }
    return $Stamp.ToString('yyyy/MM/dd HH:mm:ss')
}

function Show-RestoreLog {
    if (-not (Test-Path $LogFile)) {
        Write-Host "No backups or restores logged yet ($LogFile not found)."
        return
    }
    Write-Host ""
    Write-Host "Last Backup / Restore Times"
    Write-Host ""
    Write-Host ($RowFormat -f "Env", "Last Backup", "Backup Date", "Last Restore", "Restore Date")
    Write-Host ($RowFormat -f "---", "-----------", "-----------", "------------", "------------")
    foreach ($envName in @("dev", "qa", "snap", "prod")) {
        $backup = Get-LastLogTimestamp $envName "backup"
        $restore = Get-LastLogTimestamp $envName "restore"
        Write-Host ($RowFormat -f $envName,
            (Format-Elapsed $backup), (Format-LogDate $backup),
            (Format-Elapsed $restore), (Format-LogDate $restore))
    }
    Write-Host ""
}

# --- Command Router ---
switch ($args[0]) {
    "up"             { Run-Up }
    "down"           { Run-Down }
    "dev_backup"     { Run-DevBackup }
    "dev_restore"    { Run-DevRestore }
    "dev_refresh"    { Run-DevBackup; Run-DevRestore; Write-Host "Dev refresh complete" -ForegroundColor Green }
    "qa_backup"      { Run-QaBackup }
    "qa_restore"     { Run-QaRestore }
    "qa_refresh"     { Run-QaBackup; Run-QaRestore; Write-Host "QA refresh complete" -ForegroundColor Green }
    "snap_backup"    { Run-SnapBackup }
    "snap_restore"   { Run-SnapRestore }
    "snap_refresh"   { Run-SnapBackup; Run-SnapRestore; Write-Host "Snap refresh complete" -ForegroundColor Green }
    "prod_backup"    { Run-ProdBackup }
    "prod_restore"   { Run-ProdRestore }
    "prod_refresh"   { Run-ProdBackup; Run-ProdRestore; Write-Host "Prod refresh complete" -ForegroundColor Green }
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
