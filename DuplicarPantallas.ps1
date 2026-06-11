<#
.SYNOPSIS
    Intenta duplicar la pantalla principal en todas las demás pantallas conectadas.
    Incluye instalación automática del módulo DisplayConfig (versión 6.0.0 o superior),
    backup completo de la configuración original y restauración en caso de error.
.DESCRIPTION
    Este script fuerza la clonación en 3 o más monitores mediante Copy-DisplaySource.
    El resultado final depende del soporte de la GPU y los controladores gráficos.
    No se garantiza que funcione en todos los hardware; en caso de fallo, restaura la configuración anterior.
.NOTES
    Versión: 6.4 (validada con Get-Help de los cmdlets)
    Compatible con: DisplayConfig 6.0.0+ (MartinGC94)
#>

# ============================================================
# 1. CONFIGURACIÓN INICIAL Y SEGURIDAD
# ============================================================

# Forzar TLS 1.2 (necesario para PowerShell Gallery en Windows 10 antiguo)
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Marcar PSGallery como repositorio confiable para evitar prompts interactivos
$repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
}

# ============================================================
# 2. INSTALACIÓN DEL MÓDULO DISPLAYCONFIG (VERSIÓN 6.0.0+)
# ============================================================

$requiredVersion = [Version]"6.0.0"
$currentModule = Get-Module -ListAvailable -Name DisplayConfig |
    Where-Object { [Version]$_.Version -ge $requiredVersion } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $currentModule) {
    Write-Host "Módulo DisplayConfig versión 6.0.0 o superior no encontrado. Instalando..." -ForegroundColor Cyan
    try {
        # Intento con ámbito de usuario (no requiere admin)
        Install-Module -Name DisplayConfig -RequiredVersion "6.0.0" -Force -Scope CurrentUser -AllowClobber -Repository PSGallery -Confirm:$false -ErrorAction Stop
        Write-Host "Módulo instalado correctamente en el ámbito del usuario." -ForegroundColor Green
    }
    catch {
        # Solo elevamos si es un error de permisos
        if ($_.Exception -is [System.UnauthorizedAccessException]) {
            Write-Host "La instalación sin administrador falló por permisos. Solicitando elevación..." -ForegroundColor Yellow
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            exit
        }
        else {
            Write-Host "ERROR: No se pudo instalar DisplayConfig. Motivo: $_" -ForegroundColor Red
            Write-Host "Verifica tu conexión a internet o instala manualmente: Install-Module DisplayConfig -RequiredVersion 6.0.0 -Scope CurrentUser -Force" -ForegroundColor Yellow
            Read-Host "Presiona Enter para salir"
            exit 1
        }
    }
}
else {
    Write-Host "Módulo DisplayConfig versión $($currentModule.Version) ya está instalado." -ForegroundColor Green
}

# Importar el módulo
try {
    Import-Module DisplayConfig -ErrorAction Stop
}
catch {
    Write-Host "ERROR: No se pudo importar DisplayConfig. Reinicia PowerShell o reinstala el módulo." -ForegroundColor Red
    exit 1
}

# ============================================================
# 3. DETECCIÓN DE PANTALLAS (usando propiedades reales)
# ============================================================

$displays = Get-DisplayInfo
if (-not $displays -or $displays.Count -eq 0) {
    Write-Host "ERROR: No se pudo obtener información de pantallas. Verifica que los monitores estén conectados." -ForegroundColor Red
    exit 1
}

# Mostrar tabla diagnóstica (usando Width/Height confirmados)
Write-Host "`nPantallas detectadas:" -ForegroundColor Cyan
$displayTable = $displays | ForEach-Object {
    $res = if ($_.Mode -and $_.Mode.Width -and $_.Mode.Height) { "$($_.Mode.Width)x$($_.Mode.Height)" } else { "Desconocida" }
    [PSCustomObject]@{
        ID         = $_.DisplayId
        Nombre     = $_.DisplayName
        Principal  = $_.Primary
        Resolución = $res
        Frecuencia = if ($_.Mode) { "$($_.Mode.RefreshRate) Hz" } else { "" }
    }
}
$displayTable | Format-Table -AutoSize

# Validar que haya exactamente una pantalla principal
$principal = $displays | Where-Object { $_.Primary -eq $true }
$principalCount = ($principal | Measure-Object).Count
if ($principalCount -ne 1) {
    Write-Host "ERROR: Se esperaba exactamente una pantalla principal, pero se encontraron $principalCount." -ForegroundColor Red
    if ($principalCount -eq 0) {
        Write-Host "Configura una pantalla principal en: Pantalla > Identificar > Hacer esta mi pantalla principal." -ForegroundColor Yellow
    }
    else {
        Write-Host "`nEsto suele ocurrir porque los monitores están en modo CLONADO (duplicado)." -ForegroundColor Yellow
        Write-Host "Para solucionarlo:" -ForegroundColor Cyan
        Write-Host "  1. Presiona la tecla Windows + P" -ForegroundColor White
        Write-Host "  2. Selecciona la opción 'EXTENDER' (no 'Duplicar')" -ForegroundColor White
        Write-Host "  3. Vuelve a ejecutar este script" -ForegroundColor White
        Write-Host "`nSi el problema persiste, verifica manualmente que solo una pantalla tenga marcada la casilla 'Hacer esta mi pantalla principal' en Configuración > Pantalla." -ForegroundColor Yellow
    }
    exit 1
}
# Asegurar que obtenemos el primer elemento (funciona tanto si es array como si es escalar)
$principal = @($principal)[0]

$secundarias = $displays | Where-Object { $_.Primary -eq $false }

if ($secundarias.Count -eq 0) {
    Write-Host "INFO: No hay pantallas secundarias para duplicar. Conecta al menos un monitor externo." -ForegroundColor Yellow
    exit 0
}

if ($displays.Count -lt 3) {
    Write-Host "NOTA: Solo hay $($displays.Count) pantallas. Windows ya puede duplicar esto con Win+P. El script funcionará igual." -ForegroundColor Cyan
}

# ============================================================
# 4. BACKUP DE LA CONFIGURACIÓN ACTUAL
# ============================================================

Write-Host "`nGuardando configuración actual de pantallas (backup)..." -ForegroundColor Cyan
try {
    $backup = Get-DisplayConfig
    if (-not $backup) { throw "Get-DisplayConfig devolvió un objeto nulo." }
    Write-Host "Backup realizado correctamente." -ForegroundColor Green
}
catch {
    Write-Host "ERROR: No se pudo obtener la configuración actual. No se puede continuar de forma segura." -ForegroundColor Red
    Write-Host "Detalles: $_" -ForegroundColor Red
    exit 1
}

# ============================================================
# 5. DUPLICACIÓN (CLONACIÓN) EN TODAS LAS SECUNDARIAS
# ============================================================

Write-Host "`nIntentando duplicar pantalla principal '$($principal.DisplayName)' (ID $($principal.DisplayId)) en: $($secundarias.DisplayName -join ', ')" -ForegroundColor Cyan

try {
    # Copy-DisplaySource acepta un array en -DestinationDisplayId (documentado)
    Copy-DisplaySource -DisplayId $principal.DisplayId -DestinationDisplayId $secundarias.DisplayId -ErrorAction Stop
    Write-Host "`n✅ DUPLICACIÓN EXITOSA. Todas las pantallas muestran la misma imagen." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ ERROR AL DUPLICAR: $_" -ForegroundColor Red
    Write-Host "`nRestaurando configuración anterior..." -ForegroundColor Yellow
    try {
        $backup | Use-DisplayConfig -UpdateAdapterIds -ErrorAction Stop
        Write-Host "Configuración restaurada correctamente. El sistema ha vuelto a su estado previo." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR CRÍTICO: No se pudo restaurar la configuración. Reinicia el equipo para recuperar el estado anterior." -ForegroundColor Red
        Write-Host "Detalles del error de restauración: $_" -ForegroundColor Red
    }
    Write-Host "`nPosibles causas del fallo (dependen del hardware y controladores):" -ForegroundColor Yellow
    Write-Host "  - La tarjeta gráfica (GPU) no soporta clonación en más de 2 pantallas (limitación física)." -ForegroundColor Yellow
    Write-Host "  - Las resoluciones o frecuencias de actualización de los monitores son incompatibles." -ForegroundColor Yellow
    Write-Host "  - Los controladores (drivers) de vídeo están desactualizados o son genéricos." -ForegroundColor Yellow
    Write-Host "`nSolución alternativa: Considera un divisor HDMI activo o una matriz de conmutación (hardware)." -ForegroundColor Yellow
    exit 1
}

# ============================================================
# 6. FINALIZACIÓN
# ============================================================

Write-Host "`nScript completado." -ForegroundColor Green