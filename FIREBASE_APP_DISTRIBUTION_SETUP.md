# Firebase App Distribution

Fluxo recomendado para testes Android da equipa sem publicar na Play Store.

## O que este projeto ja deixa preparado

- script de distribuicao: `deploy_android_firebase.bat`
- script principal: `scripts/deploy_android_firebase.ps1`
- exemplo de configuracao local: `scripts/firebase_app_distribution.local.example.ps1`
- build por defeito: `APK release`

## Passo 1. Registar a app Android no Firebase

No Firebase Console:

1. criar ou escolher um projeto Firebase
2. adicionar uma app Android
3. usar exatamente este package name:

`com.micaelcunha.mantra`

Depois, copia o `Firebase App ID` da app Android.

## Passo 2. Configuracao local

Cria o ficheiro:

`scripts/firebase_app_distribution.local.ps1`

com base em:

`scripts/firebase_app_distribution.local.example.ps1`

Valores minimos:

```powershell
$env:FIREBASE_APP_ID = '1:691350615761:android:1b10bc6a2173d0751e77f0'
$env:FIREBASE_TOKEN = 'token_local_do_firebase_cli'
$env:FIREBASE_TESTERS = 'qa1@empresa.pt,qa2@empresa.pt'
```

Em vez de `FIREBASE_TOKEN`, tambem podes usar:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\caminho\para\service-account.json'
```

Se preferires, tambem podes deixar `FIREBASE_TOKEN` e
`GOOGLE_APPLICATION_CREDENTIALS` vazios e autenticar primeiro com uma sessao
local do Firebase CLI:

```powershell
npx firebase-tools@latest login --reauth --no-localhost
```

Nesse caso, o script de distribuicao reutiliza a sessao autenticada da maquina.

## Passo 3. Criar testers ou grupos

No Firebase Console > App Distribution:

- criar testers individuais por email
- ou criar grupos e usar o alias do grupo no script

## Comandos

Distribuir APK release:

```powershell
.\deploy_android_firebase.bat
```

Nota:

- ja nao precisas de editar manualmente o `pubspec.yaml` para cada update Android
- o script gera automaticamente um `build number` novo e monotono em cada build
- o estado local fica guardado em `.firebase/android-build-number-<tipo>.txt`

Distribuir APK debug:

```powershell
.\deploy_android_firebase.bat -BuildType debug
```

Gerar so a APK sem distribuir:

```powershell
.\deploy_android_firebase.bat -SkipDistribute
```

Distribuir com notas desta release:

```powershell
.\deploy_android_firebase.bat -Notes "Correcao de bugs e ajustes de procedimentos"
```

Se algum dia quiseres forcar manualmente um numero de build:

```powershell
.\deploy_android_firebase.bat -BuildNumber 260881905
```

## Onde fica a APK

- release: `build/app/outputs/flutter-apk/app-release.apk`
- debug: `build/app/outputs/flutter-apk/app-debug.apk`

## Notas operacionais

- O Firebase App Distribution mantem builds Android disponiveis por 150 dias.
- Os testers recebem convite por email e depois atualizacoes para novas builds.
- Para uploads Android, o Firebase aceita APK ou AAB; neste projeto foi escolhido `APK release` para simplificar o arranque.
