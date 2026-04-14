# Mantra

Aplicacao CMMS multiempresa em `Flutter + Supabase` para gestao de:

- ativos
- localizacoes
- ordens de trabalho
- tecnicos
- utilizadores
- empresa
- notas pessoais

## Estado atual

- isolamento multiempresa preparado com `company_id`
- perfis `admin`, `tecnico` e `cliente` validados em smoke test
- branding `Mantra` aplicado em Flutter, Web e Android
- contas geridas pela app via Supabase RPC
- anexos e documentos sensiveis resolvidos por signed URL quando aplicavel

## Desenvolvimento local

Com o Flutter configurado na maquina:

```powershell
flutter pub get
flutter run
```

Validacao basica:

```powershell
flutter test test/widget_test.dart
flutter analyze
```

## Recuperacao de Password

O login inclui agora a acao `Esqueceste-te da palavra-passe?`.

- a app envia um email de recuperacao via Supabase Auth
- o link regressa a `https://cmmscompinta.netlify.app/`
- quando o callback chega com `type=recovery`, a app web mostra o ecran para
  definir uma nova palavra-passe

Mantem o `Site URL` / redirect publico do Supabase Auth alinhado com esse
dominio para o fluxo continuar operacional.

## Branding de Icones

Para regenerar os icones da app a partir de uma imagem quadrada base:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update_app_icons.ps1 -SourceImagePath "C:\caminho\para\appstore.png"
```

O script atualiza os icones de:

- Android
- iOS
- macOS
- Windows
- Web

Tambem guarda no repositorio:

- `assets/branding/mantra_app_icon_source.png`
- `assets/branding/mantra_app_icon_foreground.png`

## Web / Netlify

A app web publicada continua a sair de `build/web`.

Para automatizar o deploy manual na Netlify nesta maquina:

1. cria `scripts/netlify.local.ps1` com base em `scripts/netlify.local.example.ps1`
2. preenche `NETLIFY_AUTH_TOKEN` e `NETLIFY_SITE_ID`
3. corre:

```powershell
.\deploy_web_netlify.bat
```

O script:

- gera `flutter build web`
- publica `build/web` na Netlify
- suporta `draft` com:

```powershell
.\deploy_web_netlify.bat -Draft
```

Se quiseres apenas gerar a build sem publicar:

```powershell
.\deploy_web_netlify.bat -SkipDeploy
```

## Scripts Supabase

Os scripts SQL principais do projeto estao na raiz:

- [SUPABASE_PRODUCT_FOUNDATION.sql](/c:/Users/pinta/asset_app/SUPABASE_PRODUCT_FOUNDATION.sql)
- [SUPABASE_MULTITENANT_RLS.sql](/c:/Users/pinta/asset_app/SUPABASE_MULTITENANT_RLS.sql)
- [SUPABASE_MULTITENANT_VALIDATION.sql](/c:/Users/pinta/asset_app/SUPABASE_MULTITENANT_VALIDATION.sql)
- [SUPABASE_PRODUCT_HARDENING.sql](/c:/Users/pinta/asset_app/SUPABASE_PRODUCT_HARDENING.sql)
- [SUPABASE_MANAGED_ACCOUNT_FLOW.sql](/c:/Users/pinta/asset_app/SUPABASE_MANAGED_ACCOUNT_FLOW.sql)

O historico operacional mais completo da app fica em [PROJECT_NOTES.md](/c:/Users/pinta/asset_app/PROJECT_NOTES.md).

## Android Release Signing

A build `release` deixou de cair automaticamente na `debug key`.

Antes de gerar APK/AAB de producao:

1. copia `android/key.properties.example` para `android/key.properties`
2. aponta `storeFile` para o teu `keystore`
3. preenche `storePassword`, `keyAlias` e `keyPassword`
4. gera a release

Exemplo:

```powershell
flutter build appbundle --release
```

Se `android/key.properties` nao existir, a build `release` falha com erro claro de configuracao em vez de assinar com a chave de debug.

## Android Beta via Firebase App Distribution

Para distribuir builds Android de teste sem publicar na Play Store:

1. regista a app Android no Firebase com o package name
   `com.micaelcunha.mantra`
2. cria `scripts/firebase_app_distribution.local.ps1` com base em
   `scripts/firebase_app_distribution.local.example.ps1`
3. corre:

```powershell
.\deploy_android_firebase.bat
```

O script passa automaticamente um `build number` novo ao `flutter build`,
por isso ja nao precisas de atualizar o `version: x.y.z+N` no `pubspec.yaml`
sempre que fores publicar uma nova build para testers.

Documentacao operacional:

- [FIREBASE_APP_DISTRIBUTION_SETUP.md](/c:/Users/pinta/asset_app/FIREBASE_APP_DISTRIBUTION_SETUP.md)

## iOS / TestFlight

O projeto ficou preparado para iOS/TestFlight com duas vias:

- local no Mac via Xcode
- remota via `Codemagic`, recomendada quando o Mac local ja nao suporta o
  Xcode exigido pela Apple

O ficheiro [codemagic.yaml](/c:/Users/pinta/asset_app/codemagic.yaml) ja deixa
uma pipeline base para build iOS assinada e upload para `App Store Connect`.

Documentacao operacional:

- [IOS_TESTFLIGHT_SETUP.md](/c:/Users/pinta/asset_app/IOS_TESTFLIGHT_SETUP.md)

No Mac, o arranque inicial continua a poder ser feito com:

```bash
bash scripts/prepare_ios_on_mac.sh
```

Sem Mac recente, a retoma recomendada e:

1. ligar o repositorio ao `Codemagic`
2. configurar a integracao Apple `mantra-app-store-connect`
3. criar o grupo `ios_remote_release` com `APP_STORE_APPLE_ID`
4. correr o workflow `ios-testflight`

## Nota operacional

Nos fluxos de eliminacao de tecnicos/utilizadores, a app tenta agora remover tambem os ficheiros associados em Supabase Storage para reduzir orfaos.
