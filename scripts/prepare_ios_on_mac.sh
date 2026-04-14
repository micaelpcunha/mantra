#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

require_command() {
  local command_name="$1"
  local install_hint="$2"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Falta o comando '${command_name}'. ${install_hint}" >&2
    exit 1
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Este script foi pensado para correr num Mac." >&2
  exit 1
fi

require_command "flutter" "Instala o Flutter no Mac e garante que esta no PATH."
require_command "xcodebuild" "Instala o Xcode e abre-o pelo menos uma vez."
require_command "pod" "Instala o CocoaPods: sudo gem install cocoapods"

cd "${REPO_ROOT}"

echo "1/4 flutter pub get"
flutter pub get

echo "2/4 limpar build iOS anterior"
rm -rf ios/Pods ios/Podfile.lock

echo "3/4 pod install"
cd ios
pod install

echo "4/4 abrir workspace no Xcode"
open Runner.xcworkspace

echo
echo "Projeto iOS preparado."
echo "No Xcode:"
echo "  1. confirma Signing & Capabilities e Team"
echo "  2. valida o Bundle Identifier"
echo "  3. escolhe um iPhone fisico ou simulador"
echo "  4. faz uma primeira execucao antes de pensar em Archive/TestFlight"
echo
echo "Depois do signing ficar certo, podes correr tambem:"
echo "  bash scripts/run_ios_debug_on_mac.sh"
