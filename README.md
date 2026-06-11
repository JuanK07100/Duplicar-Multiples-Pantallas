# Duplicar Múltiples Pantallas en Windows

Script de PowerShell que **duplica la pantalla principal en dos o más monitores externos simultáneamente**, superando la limitación nativa de Windows que solo permite clonar la pantalla en un único monitor adicional.

## 📌 ¿Por qué este script?

Windows, con la combinación `Win + P`, solo permite duplicar la pantalla principal en **una** pantalla secundaria. Si conectas dos o más monitores externos, el sistema operativo los tratará como extensiones, no como clones.

Este script utiliza el módulo **DisplayConfig** (versión 6.0.0 o superior) para crear un grupo de clonación que incluye la pantalla principal y **todas** las secundarias, logrando así la duplicación simultánea en múltiples pantallas.

## ✨ Características

- 🔁 **Duplicación real en 3, 4 o más pantallas** (dependiendo de la capacidad de la GPU).
- 💾 **Backup automático** de la configuración original de pantallas antes de aplicar cambios.
- 🔄 **Restauración automática** en caso de error (vuelve a la configuración anterior).
- 📦 **Instalación automática del módulo DisplayConfig** (sin necesidad de permisos de administrador en la mayoría de los casos).
- 📊 **Tabla de diagnóstico** que muestra las pantallas detectadas (ID, nombre, resolución, frecuencia).
- 🛑 **Manejo de errores** con mensajes claros y sugerencias de solución.
- 🧪 **Compatible con PowerShell 5.1** (incluido en Windows 10 y 11).

## ⚙️ Requisitos

- **Sistema operativo**: Windows 10 o superior.
- **PowerShell**: Versión 5.1 (la que viene por defecto).
- **Conexión a internet** (solo la primera vez, para instalar el módulo).
- **Hardware**: Tarjeta gráfica compatible con clonación en múltiples salidas. Algunas GPUs integradas (como Intel HD 4000) no soportan clonación triple; en ese caso, el script lo indicará y restaurará la configuración.

## 📦 Contenido del repositorio

- `DuplicarPantallas.ps1` – Script principal (en formato Unicode).
- `EjecutarDuplicar.bat` (opcional) – Archivo por lotes que ejecuta el script y mantiene la ventana abierta al final.
- `README.md` – Este archivo.

## 🚀 Instalación y uso

### Opción 1: Ejecución directa (recomendada)

1. Descarga el archivo `DuplicarPantallas.ps1`.
2. Haz clic derecho sobre el archivo → **"Ejecutar con PowerShell"**.
3. La primera vez se descargará e instalará automáticamente el módulo `DisplayConfig` (solicitará permisos de administrador solo si es estrictamente necesario).
4. Sigue las instrucciones en pantalla.

### Opción 2: Uso con archivo `.bat` (para mantener la ventana abierta)

Crea un archivo `EjecutarDuplicar.bat` en la misma carpeta con el siguiente contenido:

```batch
@echo off
title Duplicador de pantallas
echo Ejecutando script de duplicación...
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0DuplicarPantallas.ps1"
echo.
echo ============================================
echo Script finalizado. Presiona una tecla para cerrar.
pause > nul
```

Luego, haz doble clic en `EjecutarDuplicar.bat`.

### Opción 3: Desde una consola de PowerShell (modo avanzado)

Abre PowerShell, navega hasta la carpeta del script y ejecuta:

```powershell
.\DuplicarPantallas.ps1
```

La consola permanecerá abierta al finalizar.

## 🖥️ ¿Qué hace exactamente el script?

1. **Detecta todas las pantallas conectadas** y muestra una tabla con sus características.
2. **Verifica que haya exactamente una pantalla principal**. Si hay más de una (por ejemplo, si los monitores están en modo clonado), muestra un mensaje de error con la solución (`Win + P` → Extender).
3. **Guarda la configuración actual** de las pantallas (backup).
4. **Intenta clonar la pantalla principal** en todas las secundarias usando `Copy-DisplaySource`.
5. **Si tiene éxito** → muestra un mensaje de confirmación.
6. **Si falla** → restaura automáticamente la configuración anterior y muestra las posibles causas (limitación de GPU, incompatibilidad de resoluciones/frecuencias, drivers desactualizados).

## ❓ Solución de problemas (errores comunes)

### Error: "Se esperaba exactamente una pantalla principal, pero se encontraron 2"

**Causa más frecuente**: Los monitores están en modo **clonado** (duplicado) activado manualmente con `Win + P`.

**Solución**:
1. Presiona la tecla **Windows + P**.
2. Selecciona la opción **"Extender"** (no "Duplicar").
3. Vuelve a ejecutar el script.

> ⚠️ Si después de esto el problema persiste, verifica manualmente en *Configuración > Pantalla > Identificar* que solo una pantalla tenga marcada la casilla "Hacer esta mi pantalla principal".

### Error: "La instalación sin administrador falló por permisos"

**Causa**: El módulo DisplayConfig no se pudo instalar en el ámbito del usuario actual.

**Solución**: Ejecuta PowerShell como Administrador y vuelve a ejecutar el script. La instalación se completará correctamente.

### Error: "No se pudo obtener información de pantallas"

**Causa**: Los monitores no están correctamente conectados o hay un problema con los drivers gráficos.

**Solución**:
- Verifica que los cables HDMI/DisplayPort estén bien conectados.
- Actualiza los controladores de la tarjeta gráfica.
- Reinicia el equipo y vuelve a intentar.

### El script falla al duplicar y restaura la configuración

**Causa probable**: Limitación de hardware. No todas las GPUs soportan clonación en más de 2 pantallas simultáneamente.

**Soluciones**:
- Conecta solo dos pantallas (principal + una externa) y usa `Win + P` → "Duplicar".
- **Solución alternativa de hardware**: Utiliza un **divisor HDMI activo** (splitter) que duplique la señal por hardware.
- Actualiza los drivers de la GPU; en algunos casos, controladores más recientes amplían la compatibilidad.

### El script se cierra inmediatamente sin mostrar nada

**Causa**: La política de ejecución de scripts de PowerShell impide la ejecución.

**Solución**:
Abre PowerShell como Administrador y ejecuta:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Luego vuelve a ejecutar el script.

Si usas el archivo `.bat`, la política `Bypass` ya está incluida en el comando.

## 🛠️ Notas técnicas para administradores

- El script **no requiere que el módulo DisplayConfig esté preinstalado**; lo descarga automáticamente de la PowerShell Gallery.
- La instalación se realiza en `-Scope CurrentUser` para evitar privilegios de administrador en la mayoría de los casos.
- Se fuerza la versión **6.0.0** del módulo para garantizar compatibilidad (las propiedades usadas son `Primary`, `DisplayName`, `Mode.Width`, `Mode.Height`, `Mode.RefreshRate`).
- En caso de que ya exista una versión superior instalada, la utilizará (no se fuerza la versión exacta salvo que no haya ninguna).
- El backup se realiza mediante `Get-DisplayConfig` y la restauración con `Use-DisplayConfig -UpdateAdapterIds`.
- El script es **idempotente**: se puede ejecutar múltiples veces sin efectos secundarios no deseados.

## 📄 Licencia

Este proyecto está bajo la licencia **MIT**. Esto significa que puedes usar, copiar, modificar y distribuir el script libremente, siempre que incluyas el aviso de copyright original.

El módulo `DisplayConfig` (MartinGC94) tiene su propia licencia MIT, compatible con este proyecto.

## 👥 Créditos

- **Autor del script**: [Tu nombre o usuario de GitHub]
- **Módulo DisplayConfig**: [MartinGC94](https://github.com/MartinGC94/DisplayConfig)
- **Documentación y pruebas**: Basadas en análisis críticos y validación con `Get-Member` y `Get-Help`.

## 📬 Contacto y contribuciones

Si encuentras algún error o quieres sugerir una mejora, abre un **Issue** en este repositorio. Las contribuciones son bienvenidas mediante **Pull Requests**.

---

**¡Que disfrutes de la duplicación en todas tus pantallas!**
