[CmdletBinding()]
param(
    [ValidateSet('Install','Restore','RevertToV2','Status')][string]$Action = 'Status',
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\Lawn Mowing Simulator'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Get-Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Convert-Hex([string]$Hex) {
    [byte[]]$Result = New-Object byte[] ($Hex.Length / 2)
    for ($i = 0; $i -lt $Result.Length; $i++) { $Result[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
    return ,$Result
}
$temp = $null
try {
    $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'patch.json') -Raw | ConvertFrom-Json
    $dll = Join-Path $GamePath 'GameAssembly.dll'
    $backup = Join-Path $GamePath 'GameAssembly.dll.lms-no-overload.original.bak'
    $metadata = Join-Path $GamePath 'Lawn Mowing Simulator_Data\il2cpp_data\Metadata\global-metadata.dat'
    if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { throw "GameAssembly.dll not found in $GamePath" }
    $current = Get-Hash $dll
    if ($Action -eq 'Status') {
        if ($current -eq $manifest.original_sha256) { Write-Host 'Original supported DLL; patch is not installed.' }
        elseif ($current -eq $manifest.patched_sha256) { Write-Host 'Wide-cut v3 with flower protection is installed.' }
        elseif ($current -eq $manifest.previous_sha256) { Write-Host 'No-overload v2 is installed; run Install to upgrade to wide-cut v3.' }
        else { Write-Host 'Unrecognized DLL version. This patch will refuse to modify it.' }
        exit 0
    }
    if (@(Get-Process -Name 'Lawn Mowing Simulator' -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Close Lawn Mowing Simulator before installing or restoring.'
    }
    if ($Action -eq 'Install') {
        if ($current -eq $manifest.patched_sha256) { Write-Host 'Wide-cut v3 already installed.'; exit 0 }
        if ($current -notin @($manifest.original_sha256, $manifest.previous_sha256)) { throw 'DLL hash does not match the original or v2. No changes made.' }
        if ((Get-Hash $metadata) -ne $manifest.metadata_sha256) { throw 'Game metadata version does not match. No changes made.' }
        [byte[]]$data = [IO.File]::ReadAllBytes($dll)
        if ($current -eq $manifest.previous_sha256) {
            if (-not (Test-Path -LiteralPath $backup)) { throw 'Original v2 backup is missing. Restore the official game files before installing v3.' }
            if ((Get-Hash $backup) -ne $manifest.original_sha256) { throw 'Original backup does not match.' }
            foreach ($prior in $manifest.previous_patches) {
                [byte[]]$priorNew = Convert-Hex $prior.replacement
                [byte[]]$priorOld = Convert-Hex $prior.original
                for ($i = 0; $i -lt $priorNew.Length; $i++) {
                    if ($data[[int]$prior.offset + $i] -ne $priorNew[$i]) { throw 'Unexpected v2 patch bytes.' }
                }
                [Array]::Copy($priorOld, 0, $data, [int]$prior.offset, $priorOld.Length)
            }
        }
        foreach ($patch in $manifest.patches) {
            [byte[]]$old = Convert-Hex $patch.original
            [byte[]]$new = Convert-Hex $patch.replacement
            if ($old.Length -ne $new.Length) { throw 'Invalid patch lengths.' }
            for ($i = 0; $i -lt $old.Length; $i++) {
                if ($data[[int]$patch.offset + $i] -ne $old[$i]) { throw "Unexpected bytes at $($patch.name)." }
            }
            [Array]::Copy($new, 0, $data, [int]$patch.offset, $new.Length)
        }
        if (Test-Path -LiteralPath $backup) {
            if ((Get-Hash $backup) -ne $manifest.original_sha256) { throw 'Existing backup is not the expected original. It will not be overwritten.' }
        } else {
            [IO.File]::Copy($dll, $backup, $false)
            if ((Get-Hash $backup) -ne $manifest.original_sha256) { throw 'Backup verification failed.' }
        }
        $temp = Join-Path $GamePath ('LMS-NoOverload-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::WriteAllBytes($temp, $data)
        if ((Get-Hash $temp) -ne $manifest.patched_sha256) { throw 'Patched output verification failed; original DLL was not replaced.' }
        if ((Get-Hash $dll) -ne $current) { throw 'Game DLL changed during installation. Aborting.' }
        [IO.File]::Replace($temp, $dll, [System.Management.Automation.Language.NullString]::Value)
        $temp = $null
        if ((Get-Hash $dll) -ne $manifest.patched_sha256) { throw 'Post-install verification failed. Use Restore.' }
        Write-Host 'Experimental wide-cut v3 with flower protection installed. Original DLL backup verified.'
        Write-Host 'Launch the game normally through Steam and test mowing a thick patch.'
    } else {
        if ($current -eq $manifest.original_sha256 -and $Action -eq 'Restore') { Write-Host 'Original DLL is already installed.'; exit 0 }
        if ($current -notin @($manifest.patched_sha256, $manifest.previous_sha256, $manifest.original_sha256)) { throw 'DLL has changed since this patch. Refusing to overwrite a different version.' }
        if ((Get-Hash $backup) -ne $manifest.original_sha256) { throw 'Original backup is missing or does not match.' }
        $temp = Join-Path $GamePath ('LMS-Restore-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::Copy($backup, $temp, $false)
        if ((Get-Hash $temp) -ne $manifest.original_sha256) { throw 'Restore copy verification failed.' }
        $restoreHash = $manifest.original_sha256
        if ($Action -eq 'RevertToV2') {
            [byte[]]$restoreData = [IO.File]::ReadAllBytes($temp)
            foreach ($prior in $manifest.previous_patches) {
                [byte[]]$priorOld = Convert-Hex $prior.original
                [byte[]]$priorNew = Convert-Hex $prior.replacement
                for ($i = 0; $i -lt $priorOld.Length; $i++) {
                    if ($restoreData[[int]$prior.offset + $i] -ne $priorOld[$i]) { throw 'Unexpected bytes during v2 restore.' }
                }
                [Array]::Copy($priorNew, 0, $restoreData, [int]$prior.offset, $priorNew.Length)
            }
            [IO.File]::WriteAllBytes($temp, $restoreData)
            $restoreHash = $manifest.previous_sha256
            if ((Get-Hash $temp) -ne $restoreHash) { throw 'V2 restore verification failed.' }
        }
        if ((Get-Hash $dll) -ne $current) { throw 'Game DLL changed during restore. Aborting.' }
        [IO.File]::Replace($temp, $dll, [System.Management.Automation.Language.NullString]::Value)
        $temp = $null
        if ((Get-Hash $dll) -ne $restoreHash) { throw 'Post-restore verification failed.' }
        if ($Action -eq 'RevertToV2') { Write-Host 'Working no-overload v2 restored. Backup retained.' } else { Write-Host 'Original game DLL restored. Backup retained.' }
    }
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'If access was denied, reopen PowerShell as administrator and run the same command.'
    exit 1
} finally {
    if ($temp -and (Test-Path -LiteralPath $temp)) { Remove-Item -LiteralPath $temp -Force }
}
