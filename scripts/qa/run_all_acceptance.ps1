param(
  [string]$Serial = "T4E6S8IFU4AQBM8L",
  [string]$MaestroExe = "C:\Users\Mr Huy\maestro\maestro\bin\maestro.bat",
  [string]$OutDir = "test-results\all_acceptance",
  [int]$TimeoutMin = 15,
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [string]$ApkPath = "build\app\outputs\flutter-apk\app-debug.apk",
  [string]$OtherApp = "com.android.settings"
)
<#==============================================================================
  Chạy TOÀN BỘ test nghiệm thu Maestro của e_recorder.
  Mỗi file YAML trong maestro/ được chạy một lần, ứng dụng được dọn sạch giữa
  các lần chạy (force-stop + về màn hình chính) để không bị dính trạng thái.

  Yêu cầu:
  - Máy thật đã kết nối adb, màn hình mở khóa, giữ sáng.
  - Java tool options UTF-8 (chữ có dấu không bị hỏng).
  - Maestro CLI (bản 2.11.0+, tải từ GitHub chính thức, KHÔNG dùng gói npm).

  Ví dụ:
    .\scripts\qa\run_all_acceptance.ps1
    .\scripts\qa\run_all_acceptance.ps1 -Serial R5CY6323KMX -OtherApp com.sec.android.app.popupcalculator -SkipBuild -SkipInstall
==============================================================================#>
$ErrorActionPreference = "Continue"
$env:MSYS_NO_PATHCONV = "1"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$appId = "com.huluca.escreenrecorder"

New-Item -ItemType Directory -Force $OutDir | Out-Null
$csv = Join-Path $OutDir "results.csv"
"group,flow,exit,first_failure,screenshot_dir" | Set-Content $csv -Encoding UTF8

function Force-CleanDevice {
  adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
  $pkgs = @($appId, "dev.mobile.maestro", "dev.mobile.maestro.test",
    "com.google.android.documentsui", "com.android.documentsui",
    "com.sec.android.app.myfiles", "com.google.android.apps.photos",
    "com.android.settings", "com.sec.android.app.popupcalculator")
  foreach ($pkg in $pkgs) { adb -s $Serial shell am force-stop $pkg 2>$null | Out-Null }
  adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
  adb -s $Serial shell cmd statusbar collapse 2>$null | Out-Null
}

function Run-OneFlow {
  param([string]$Group, [string]$FlowName, [string]$ExtraArgs = "")
  $flowFile = "maestro\$FlowName.yaml"
  if (-not (Test-Path $flowFile)) {
    "$Group,$FlowName,1,MISSING_FILE,$null" | Add-Content $csv -Encoding UTF8
    Write-Output "  [SKIP] $FlowName (file không tồn tại)"
    return
  }
  Force-CleanDevice
  $log = Join-Path $OutDir "$($FlowName).log"
  $testOut = Join-Path $OutDir $FlowName
  $args = @("--device", $Serial, "test", "--test-output-dir", $testOut)
  if ($ExtraArgs) { $args += $ExtraArgs.Split(" ") }
  $args += $flowFile
  Write-Output "  [RUN] $FlowName ..."
  $p = Start-Process -FilePath $MaestroExe -ArgumentList $args -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -NoNewWindow
  $null = $p.Handle
  if (-not $p.WaitForExit($TimeoutMin * 60000)) {
    Stop-Process -Id $p.Id -Force
    $code = 124
  } else {
    $p.WaitForExit()
    $code = $p.ExitCode
  }
  $fail = ""
  if ($code -ne 0) {
    $m = Select-String -Path $log -Pattern "FAILED|Assertion is false|Element not found|Timed out" -SimpleMatch:$false | Select-Object -First 1
    if ($m) { $fail = ($m.Line -replace ",", ";").Trim() }
    elseif ($code -eq 124) { $fail = "timeout" }
  }
  "$Group,$FlowName,$code,$fail,$testOut" | Add-Content $csv -Encoding UTF8
  $status = if ($code -eq 0) { "PASS" } else { "FAIL ($code)" }
  Write-Output "  [$status] $FlowName $fail"
}

#-------------------------------------------------------------------------------
# 0. Build + cài APK
#-------------------------------------------------------------------------------
if (-not $SkipBuild) {
  Write-Output "== Build APK debug =="
  & flutter build apk --debug 2>&1 | Select-Object -Last 5
  if ($LASTEXITCODE -ne 0) { Write-Error "Build APK thất bại"; exit 1 }
}
if (-not $SkipInstall) {
  if (-not (Test-Path $ApkPath)) { Write-Error "Không tìm thấy APK: $ApkPath (chạy --SkipBuild nếu đã cài)"; exit 1 }
  Write-Output "== Cài APK lên thiết bị =="
  adb -s $Serial install -r $ApkPath | Out-Null
}

#-------------------------------------------------------------------------------
# Định nghĩa nhóm test (theo thứ tự ưu tiên nghiệm thu)
#-------------------------------------------------------------------------------
$groups = [ordered]@{
  "P0_Smoke_Core" = @(
    "g0_smoke",
    "g1_record",
    "g1_library",
    "g1_no_bar"
  )
  "P1_Record_Markers" = @(
    "g2_marker_gallery",
    "g2_live_markers",
    "g5_dot_mode",
    "g6_clean_mode",
    "g7_auto_direct",
    "ux_modes_record",
    "ux_mark_timing"
  )
  "P1_Editor" = @(
    "g3_editor",
    "g3_gif",
    "g3_join",
    "g3_project",
    "g4_onboarding",
    "e1_edit_core",
    "e2_overlays",
    "e2b_crop_rotate",
    "e2_pick_probe",
    "e2_pip_s25",
    "e3_motion",
    "e4_audio",
    "e4_audio_s25",
    "e4_voice_permission",
    "e7_background",
    "e8_tools_zoom",
    "e9_subtitles",
    "e10_regions",
    "e11_region_motion",
    "e12_waveform",
    "e13_pick_video",
    "e14_pip_portrait",
    "e16_build_from_touches",
    "e17_auto_captions",
    "e18_text_fx"
  )
  "P1_Caption" = @(
    "caption_phase2_smoke",
    "caption_auto_flow",
    "caption_phase3_reveal",
    "caption_phase4_style",
    "caption_phase5_templates",
    "caption_phase7_export",
    "caption_phase7_full",
    "caption_phase7_speed",
    "caption_rollback_effects",
    "caption_rollback_export",
    "caption_srt_import"
  )
  "P1_UX_RealUser" = @(
    "ux_real_user",
    "ux_swipe_guide",
    "ux_editor_modes",
    "ux_kill_recording",
    "ux_long_export",
    "ux_long_kill_a",
    "ux_long_kill_b",
    "ux_mic_denied",
    "ux_ready_a",
    "ux_ready_b",
    "ux_third_party"
  )
  "Presets" = @(
    "preset_tutorial",
    "preset_game",
    "preset_game_landscape",
    "preset_plain"
  )
  "Store" = @(
    "store_en",
    "store_vi",
    "store_pro",
    "store_video_a",
    "store_video_b",
    "store_export_demo"
  )
  "Other" = @(
    "s1_icon_audit",
    "test_zoom_s25",
    "export_current",
    "back_to_record"
  )
}

#-------------------------------------------------------------------------------
# Chạy từng nhóm
#-------------------------------------------------------------------------------
$total = 0; $passed = 0; $failed = 0
foreach ($groupName in $groups.Keys) {
  $flows = $groups[$groupName]
  Write-Output ""
  Write-Output "=============================================="
  Write-Output "  NHÓM: $groupName  ($($flows.Count) test)"
  Write-Output "=============================================="
  foreach ($f in $flows) {
    $total++
    $extra = ""
    if (@("g7_auto_direct","g5_dot_mode","g6_clean_mode","ux_real_user","ux_mark_timing","ux_modes_record") -contains $f) {
      $extra = "-e OTHER_APP=$OtherApp"
    }
    Run-OneFlow -Group $groupName -FlowName $f -ExtraArgs $extra
    if ($LASTEXITCODE -eq 0) { $passed++ } else { $failed++ }
  }
}

#-------------------------------------------------------------------------------
# Tổng kết
#-------------------------------------------------------------------------------
Write-Output ""
Write-Output "=============================================="
Write-Output "  TỔNG KẾT NGHIỆM THU TOÀN BỘ"
Write-Output "=============================================="
Write-Output "  Tổng số test : $total"
Write-Output "  Đạt          : $passed"
Write-Output "  Không đạt    : $failed"
Write-Output "  File kết quả : $csv"
Write-Output "=============================================="

if ($failed -gt 0) { exit 1 }