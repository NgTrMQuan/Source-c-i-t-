@echo off
:: ============================================================
::  XÓA SẠCH AUTODESK (Clean Uninstall) - tự động
::  Làm theo bài hướng dẫn chính thức của Autodesk:
::  https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/Clean-uninstall.html
::  Cách dùng: bấm đúp file này, chọn Yes khi Windows hỏi quyền Administrator.
::  Nhật ký (log) lưu ra Desktop: XoaSachAutodesk_<ngày-giờ>.log
:: ============================================================
chcp 65001 >nul
net session >nul 2>&1
if errorlevel 1 (
  echo Dang xin quyen Administrator...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "XS_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText($env:XS_SELF,[Text.Encoding]::UTF8); $i=$c.LastIndexOf('#'+'#PS_START'); Invoke-Expression $c.Substring($i)"
echo.
pause
exit /b

##PS_START
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# Cửa sổ CMD mặc định có thể dùng font Raster (không có chữ tiếng Việt) -> đổi sang font TrueType có dấu
try {
  Add-Type -ErrorAction Stop -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class XsCon {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CFI { public uint cbSize; public uint nFont; public short X; public short Y; public int Family; public int Weight;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Face; }
  [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr GetStdHandle(int h);
  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool SetCurrentConsoleFontEx(IntPtr h, bool max, ref CFI f);
  [DllImport("kernel32.dll")] static extern bool SetConsoleOutputCP(uint cp);
  [DllImport("kernel32.dll")] static extern bool SetConsoleCP(uint cp);
  public static bool Fix(string face) {
    SetConsoleOutputCP(65001); SetConsoleCP(65001);
    CFI f = new CFI(); f.cbSize = (uint)Marshal.SizeOf(f); f.Y = 18; f.Family = 54; f.Weight = 400; f.Face = face;
    return SetCurrentConsoleFontEx(GetStdHandle(-11), false, ref f);
  }
}
'@
  if (-not [XsCon]::Fix('Consolas')) { [void][XsCon]::Fix('Lucida Console') }
  [Console]::OutputEncoding = [Text.Encoding]::UTF8
} catch {}
$Host.UI.RawUI.WindowTitle = 'Xóa sạch Autodesk'

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
$logFile = Join-Path $desktop "XoaSachAutodesk_$stamp.log"
$bakDir  = Join-Path $desktop "XoaSachAutodesk_SaoLuuRegistry_$stamp"
$results = New-Object System.Collections.ArrayList

function Log([string]$msg, [string]$color = 'Gray') {
  $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
  Write-Host $line -ForegroundColor $color
  Add-Content -Path $logFile -Value $line -Encoding UTF8
}
function Result([string]$step, [string]$item, [string]$status, [string]$detail = '') {
  [void]$results.Add([pscustomobject]@{ 'Bước' = $step; 'Mục' = $item; 'Kết quả' = $status; 'Chi tiết' = $detail })
  $c = @{ 'OK' = 'Green'; 'BỎ QUA' = 'DarkGray'; 'LỖI' = 'Red'; 'CÒN SÓT' = 'Yellow' }[$status]; if (-not $c) { $c = 'Gray' }
  Log ("  [{0}] {1} {2}" -f $status, $item, $detail) $c
}
function Run-Exe([string]$file, [string]$argList, [int]$timeoutMin = 30) {
  try {
    $p = Start-Process -FilePath $file -ArgumentList $argList -PassThru -WindowStyle Hidden -ErrorAction Stop
    if (-not $p.WaitForExit($timeoutMin * 60000)) { try { $p.Kill() } catch {}; return -999 }
    return $p.ExitCode
  } catch { return -1 }
}
function Get-AdskApps {
  $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
           'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
           'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    Get-ChildItem $r -ErrorAction SilentlyContinue | ForEach-Object {
      $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
      if ($p.DisplayName -and ($p.Publisher -like '*Autodesk*' -or $p.DisplayName -like 'Autodesk*') -and -not $p.SystemComponent) {
        [pscustomobject]@{ Name = $p.DisplayName; Version = $p.DisplayVersion; Key = $_.PSChildName; Path = $_.PSPath
          Msi = ($p.WindowsInstaller -eq 1 -or $_.PSChildName -match '^\{[0-9A-F-]{36}\}$')
          Uninst = $p.UninstallString; Quiet = $p.QuietUninstallString }
      }
    }
  }
}

Clear-Host
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host '   XÓA SẠCH PHẦN MỀM AUTODESK (Clean Uninstall tự động)' -ForegroundColor Cyan
Write-Host '================================================================' -ForegroundColor Cyan
Log "Bắt đầu. Máy: $env:COMPUTERNAME  -  Người dùng: $env:USERNAME"
Log "Log: $logFile"

$apps = @(Get-AdskApps | Sort-Object Name -Unique)
Write-Host ''
Write-Host "Tìm thấy $($apps.Count) mục Autodesk đã cài:" -ForegroundColor White
$apps | ForEach-Object { Write-Host ("   - {0} {1}" -f $_.Name, $_.Version) }
Write-Host ''
Write-Host 'CẢNH BÁO: Công cụ sẽ gỡ TOÀN BỘ phần mềm Autodesk, xóa thư mục, registry và thông tin license.' -ForegroundColor Yellow
Write-Host 'Nếu có family, template, thư viện tùy biến trong thư mục Autodesk, hãy sao lưu trước.' -ForegroundColor Yellow
Write-Host ''
Write-Host '  1 = Chỉ KIỂM TRA (liệt kê những gì sẽ bị xóa, không xóa gì)'
Write-Host '  2 = XÓA SẠCH'
Write-Host '  Phím khác = Thoát'
$mode = Read-Host 'Chọn'
$dry = $true
if ($mode -eq '2') {
  $ok = Read-Host 'Gõ XOA (chữ in hoa) để xác nhận xóa sạch'
  if ($ok -ne 'XOA') { Log 'Đã hủy, không thay đổi gì.' 'Yellow'; return }
  $dry = $false
} elseif ($mode -ne '1') { Log 'Đã thoát, không thay đổi gì.'; return }
Log ($(if ($dry) { 'CHẾ ĐỘ KIỂM TRA - không xóa gì' } else { 'CHẾ ĐỘ XÓA SẠCH' })) 'Cyan'

# ---------- 0. Dừng tiến trình và dịch vụ Autodesk ----------
Log '0. Dừng chương trình và dịch vụ Autodesk đang chạy' 'Cyan'
$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and ($_.Path -like '*\Autodesk*' -or $_.Path -like '*\AdODIS*') }
foreach ($p in $procs) {
  if ($dry) { Result '0' "Tiến trình $($p.ProcessName)" 'BỎ QUA' '(kiểm tra)'; continue }
  try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Result '0' "Tiến trình $($p.ProcessName)" 'OK' 'đã dừng' } catch { Result '0' "Tiến trình $($p.ProcessName)" 'LỖI' $_.Exception.Message }
}
$svcs = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName -match 'Autodesk|AdskLicensing|AdODIS|FLEXnet' -or $_.DisplayName -match 'Autodesk' }
foreach ($s in $svcs) {
  if ($dry) { Result '0' "Dịch vụ $($s.DisplayName)" 'BỎ QUA' '(kiểm tra)'; continue }
  try { Stop-Service -Name $s.Name -Force -ErrorAction Stop; Result '0' "Dịch vụ $($s.DisplayName)" 'OK' 'đã dừng' } catch { Result '0' "Dịch vụ $($s.DisplayName)" 'BỎ QUA' 'không dừng được hoặc đã dừng' }
}

# ---------- 1. Gỡ phần mềm Autodesk (trừ Genuine Service) ----------
Log '1. Gỡ cài đặt phần mềm Autodesk (trừ Autodesk Genuine Service)' 'Cyan'
foreach ($a in ($apps | Where-Object { $_.Name -notlike '*Genuine Service*' })) {
  if ($dry) { Result '1' $a.Name 'BỎ QUA' '(kiểm tra) sẽ được gỡ'; continue }
  $code = $null
  if ($a.Msi -and $a.Key -match '^\{') {
    $code = Run-Exe 'msiexec.exe' "/x $($a.Key) /qn /norestart"
  } else {
    $cmd = if ($a.Quiet) { $a.Quiet } else { $a.Uninst }
    if ($cmd) {
      if ($cmd -match 'Installer\.exe' -and $cmd -notmatch '--silent') { $cmd += ' --silent' }
      if ($cmd -match 'uninstall\.exe' -and $cmd -notmatch '--mode') { $cmd += ' --mode unattended' }
      if ($cmd -match '^\s*"([^"]+)"\s*(.*)$') { $code = Run-Exe $matches[1] $matches[2] }
      elseif ($cmd -match '^\s*(\S+\.exe)\s*(.*)$') { $code = Run-Exe $matches[1] $matches[2] }
    }
  }
  if ($code -in 0, 3010, 1641, 1605, 1614) { Result '1' $a.Name 'OK' ("đã gỡ (mã {0})" -f $code) }
  elseif ($code -eq -999) { Result '1' $a.Name 'LỖI' 'quá 30 phút, đã dừng' }
  elseif ($null -eq $code) { Result '1' $a.Name 'LỖI' 'không có lệnh gỡ' }
  else { Result '1' $a.Name 'LỖI' ("mã lỗi {0}" -f $code) }
}
$odis = 'C:\Program Files\Autodesk\AdODIS\V1\RemoveODIS.exe'
if (Test-Path $odis) {
  if ($dry) { Result '1' 'Autodesk ODIS (RemoveODIS.exe)' 'BỎ QUA' '(kiểm tra) sẽ được gỡ' }
  else { $c = Run-Exe $odis '--mode unattended' 15; Result '1' 'Autodesk ODIS (RemoveODIS.exe)' ($(if ($c -eq 0) { 'OK' } else { 'LỖI' })) "mã $c" }
} else { Result '1' 'Autodesk ODIS' 'BỎ QUA' 'không có trên máy' }
$lic = 'C:\Program Files (x86)\Common Files\Autodesk Shared\AdskLicensing\uninstall.exe'
if (Test-Path $lic) {
  if ($dry) { Result '1' 'Autodesk Licensing Desktop Service' 'BỎ QUA' '(kiểm tra) sẽ được gỡ' }
  else { $c = Run-Exe $lic '--mode unattended' 15; Result '1' 'Autodesk Licensing Desktop Service' ($(if ($c -eq 0) { 'OK' } else { 'LỖI' })) "mã $c" }
} else { Result '1' 'Autodesk Licensing Desktop Service' 'BỎ QUA' 'không có trên máy' }

# ---------- 2. Gỡ Autodesk Identity Manager ----------
Log '2. Gỡ Autodesk Identity Manager' 'Cyan'
$idm = 'C:\Program Files\Autodesk\AdskIdentityManager\uninstall.exe'
if (Test-Path $idm) {
  if ($dry) { Result '2' 'Autodesk Identity Manager' 'BỎ QUA' '(kiểm tra) sẽ được gỡ' }
  else { $c = Run-Exe $idm '--mode unattended' 15; Result '2' 'Autodesk Identity Manager' ($(if ($c -eq 0) { 'OK' } else { 'LỖI' })) "mã $c" }
} else { Result '2' 'Autodesk Identity Manager' 'BỎ QUA' 'không có trên máy' }

# ---------- 3. Xóa file và thư mục ----------
Log '3. Xóa file tạm, license FLEXnet và thư mục Autodesk' 'Cyan'
$tmp = [IO.Path]::GetTempPath()
$tmpItems = @(Get-ChildItem -LiteralPath $tmp -Force -ErrorAction SilentlyContinue)
if ($dry) { Result '3' "Thư mục Temp ($tmp)" 'BỎ QUA' "(kiểm tra) $($tmpItems.Count) mục" }
else {
  $tmpItems | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
  $left = @(Get-ChildItem -LiteralPath $tmp -Force -ErrorAction SilentlyContinue).Count
  Result '3' "Thư mục Temp ($tmp)" ($(if ($left -eq 0) { 'OK' } else { 'CÒN SÓT' })) ("đã xóa {0}/{1} mục, {2} mục đang bị khóa được bỏ qua" -f ($tmpItems.Count - $left), $tmpItems.Count, $left)
}
$flex = @(Get-ChildItem -LiteralPath 'C:\ProgramData\FLEXnet' -Filter 'adsk*' -Force -ErrorAction SilentlyContinue)
if ($flex.Count -eq 0) { Result '3' 'C:\ProgramData\FLEXnet\adsk*' 'BỎ QUA' 'không có file' }
foreach ($f in $flex) {
  if ($dry) { Result '3' $f.FullName 'BỎ QUA' '(kiểm tra) sẽ bị xóa'; continue }
  try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; Result '3' $f.FullName 'OK' 'đã xóa' } catch { Result '3' $f.FullName 'LỖI' $_.Exception.Message }
}
$folders = 'C:\Program Files\Autodesk', 'C:\Program Files\Common Files\Autodesk Shared',
           'C:\Program Files (x86)\Autodesk', 'C:\Program Files (x86)\Common Files\Autodesk Shared',
           'C:\ProgramData\Autodesk', (Join-Path $env:LOCALAPPDATA 'Autodesk'), (Join-Path $env:APPDATA 'Autodesk')
foreach ($d in $folders) {
  if (-not (Test-Path -LiteralPath $d)) { Result '3' $d 'BỎ QUA' 'không tồn tại'; continue }
  if ($dry) { $n = @(Get-ChildItem -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue).Count; Result '3' $d 'BỎ QUA' "(kiểm tra) $n mục sẽ bị xóa"; continue }
  Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $d) {
    $n = @(Get-ChildItem -LiteralPath $d -Recurse -Force -File -ErrorAction SilentlyContinue).Count
    Result '3' $d 'CÒN SÓT' "còn $n file đang bị khóa - khởi động lại máy rồi chạy lại công cụ"
  } else { Result '3' $d 'OK' 'đã xóa' }
}

# ---------- 4. Xóa registry ----------
Log '4. Xóa khóa registry Autodesk (có sao lưu trước)' 'Cyan'
$keys = @(@('HKLM\SOFTWARE\Autodesk', 'HKLM:\SOFTWARE\Autodesk'),
          @('HKLM\SOFTWARE\WOW6432Node\Autodesk', 'HKLM:\SOFTWARE\WOW6432Node\Autodesk'),
          @('HKCU\SOFTWARE\Autodesk', 'HKCU:\SOFTWARE\Autodesk'))
foreach ($k in $keys) {
  if (-not (Test-Path $k[1])) { Result '4' $k[0] 'BỎ QUA' 'không tồn tại'; continue }
  if ($dry) { Result '4' $k[0] 'BỎ QUA' '(kiểm tra) sẽ được sao lưu rồi xóa'; continue }
  if (-not (Test-Path $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
  $bak = Join-Path $bakDir (($k[0] -replace '[\\ ]', '_') + '.reg')
  & reg.exe export $k[0] $bak /y | Out-Null
  & reg.exe delete $k[0] /f | Out-Null
  if (Test-Path $k[1]) { Result '4' $k[0] 'LỖI' 'không xóa được' } else { Result '4' $k[0] 'OK' "đã xóa (sao lưu: $bak)" }
}

# ---------- 5. Gỡ Autodesk Genuine Service ----------
Log '5. Gỡ Autodesk Genuine Service' 'Cyan'
$gs = @(Get-AdskApps | Where-Object { $_.Name -like '*Genuine Service*' })
if ($gs.Count -eq 0) { Result '5' 'Autodesk Genuine Service' 'BỎ QUA' 'không có trên máy' }
foreach ($g in $gs) {
  if ($dry) { Result '5' $g.Name 'BỎ QUA' '(kiểm tra) sẽ được gỡ'; continue }
  $c = if ($g.Key -match '^\{') { Run-Exe 'msiexec.exe' "/x $($g.Key) /qn /norestart" 15 } else { -1 }
  if ($c -in 0, 3010, 1605) { Result '5' $g.Name 'OK' "đã gỡ (mã $c)" } else { Result '5' $g.Name 'LỖI' "mã $c - gỡ thủ công trong Control Panel" }
}

# ---------- Kiểm tra lại ----------
if (-not $dry) {
  Log 'Kiểm tra lại phần mềm Autodesk còn sót' 'Cyan'
  $left = @(Get-AdskApps)
  if ($left.Count -eq 0) { Result 'KT' 'Danh sách Programs and Features' 'OK' 'không còn mục Autodesk' }
  foreach ($l in $left) { Result 'KT' $l.Name 'CÒN SÓT' 'gỡ thủ công hoặc dùng Microsoft Program Install and Uninstall Troubleshooter' }
}

# ---------- Tổng kết ----------
$ok = @($results | Where-Object 'Kết quả' -eq 'OK').Count
$err = @($results | Where-Object 'Kết quả' -eq 'LỖI').Count
$rem = @($results | Where-Object 'Kết quả' -eq 'CÒN SÓT').Count
$skip = @($results | Where-Object 'Kết quả' -eq 'BỎ QUA').Count
Add-Content -Path $logFile -Value "`r`n================ BẢNG KẾT QUẢ ================" -Encoding UTF8
$results | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Add-Content -Path $logFile -Encoding UTF8
Write-Host ''
Write-Host '================ TỔNG KẾT ================' -ForegroundColor Cyan
Write-Host ("  Thành công : {0}" -f $ok) -ForegroundColor Green
Write-Host ("  Còn sót    : {0}" -f $rem) -ForegroundColor Yellow
Write-Host ("  Lỗi        : {0}" -f $err) -ForegroundColor Red
Write-Host ("  Bỏ qua     : {0}" -f $skip) -ForegroundColor DarkGray
Write-Host "  Log chi tiết: $logFile"
if (-not $dry) { Write-Host '  Hãy KHỞI ĐỘNG LẠI máy trước khi cài lại phần mềm Autodesk.' -ForegroundColor Yellow }
Add-Content -Path $logFile -Value ("Tổng kết: thành công {0}, còn sót {1}, lỗi {2}, bỏ qua {3}" -f $ok, $rem, $err, $skip) -Encoding UTF8
Start-Process notepad.exe $logFile
