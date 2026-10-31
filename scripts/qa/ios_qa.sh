#!/bin/bash
# Runs on the Mac. Builds and tests the e_recorder clone in ~/e_recorder_ios_qa/src, one log per step.
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export PATH="$HOME/flutter/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
Q=~/e_recorder_ios_qa
L=$Q/logs
mkdir -p "$L"; rm -f "$L"/*
cd "$Q/src" || exit 1
step() { # name, command...
  local n=$1; shift
  local t0=$(date +%s)
  echo "=== $n: $*" > "$L/$n.log"
  ( "$@" ) >> "$L/$n.log" 2>&1
  local rc=$?
  echo "$n,$rc,$(( $(date +%s) - t0 ))s" >> "$L/summary.csv"
  return $rc
}
{
  echo "date=$(date)"; sw_vers; xcodebuild -version; flutter --version; pod --version
  echo "HEAD=$(git rev-parse HEAD)"
} > "$L/00_env.log" 2>&1
step 01_plutil plutil -lint ios/Runner/Info.plist
step 02_pub_get flutter pub get
step 03_pod_install bash -c 'cd ios && pod install'
step 04_test flutter test
step 05_analyze flutter analyze
step 06_build_sim flutter build ios --simulator --debug
step 07_build_device flutter build ios --no-codesign
git status --short > "$L/git_status_after.txt"
echo DONE >> "$L/summary.csv"
