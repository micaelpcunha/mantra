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
require_command "pod" "Instala o CocoaPods: sudo gem install cocoapods"

cd "${REPO_ROOT}"

echo "1/4 flutter pub get"
flutter pub get

echo "2/4 pod install"
cd ios
pod install
cd "${REPO_ROOT}"

echo "3/4 dispositivos iOS detetados"
flutter devices

echo "4/4 arranque iOS debug"
echo "Se o signing ainda nao estiver configurado, abre primeiro ios/Runner.xcworkspace no Xcode."
flutter run
