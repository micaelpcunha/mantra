# iOS TestFlight Setup

Preparacao para levar a app iOS do projeto `Mantra` para TestFlight.

Neste momento, o caminho recomendado para este projeto e remoto via
`Codemagic`, porque a Apple exige Xcode recente para uploads iOS e esse Mac
local ja nao acompanha bem essa frente.

## Estado ja preparado neste repositorio

- nome visivel da app em iPhone: `Mantra`
- bundle identifier iOS alinhado para `com.micaelcunha.mantra`
- `Podfile` iOS criado
- `Debug.xcconfig` e `Release.xcconfig` preparados para CocoaPods
- permissao de camara presente para leitura de QR
- permissao de fotografias presente para anexar imagens
- target minimo iOS: `13.0`
- pipeline remota base em [codemagic.yaml](/c:/Users/pinta/asset_app/codemagic.yaml)

## Caminho recomendado sem Mac recente

Servico escolhido: `Codemagic`

Porque faz sentido aqui:

- corre builds Flutter + iOS em macOS remoto
- suporta signing iOS com App Store Connect API key
- permite gerar `.ipa` assinada e enviar para App Store Connect
- evita depender do teu Mac antigo para `Archive` / upload

## O que precisas antes da primeira build remota

1. colocar o projeto num repositorio Git remoto (`GitHub`, `GitLab` ou
   `Bitbucket`)
2. criar a app no `App Store Connect` com o bundle id:

`com.micaelcunha.mantra`

3. apontar o repo no `Codemagic`
4. criar uma integracao `App Store Connect API key` no Codemagic com o nome:

`mantra-app-store-connect`

5. criar no Codemagic um grupo de variaveis com o nome:

`ios_remote_release`

6. dentro desse grupo, guardar pelo menos:
   - `APP_STORE_APPLE_ID`: Apple ID numerico da app no App Store Connect

## Configuracao de signing no Codemagic

No `Codemagic`:

1. abrir `Team settings`
2. abrir `codemagic.yaml settings`
3. abrir `Code signing identities`
4. ligar a integracao Apple criada acima
5. fazer `Fetch profiles`
6. escolher certificados / provisioning profiles `App Store` para:

`com.micaelcunha.mantra`

O `codemagic.yaml` ja esta preparado para usar `distribution_type: app_store`
e aplicar os perfis com `xcode-project use-profiles`.

## Primeira build remota

Depois da integracao e do signing:

1. abrir a app no `Codemagic`
2. escolher o workflow:

`ios-testflight`

3. arrancar build manual
4. esperar pela geracao da `.ipa` e upload para `App Store Connect`

Notas sobre esta pipeline:

- usa `Xcode 26.2.x`
- calcula automaticamente o `build number`
- reaproveita o `build name` do `pubspec.yaml`
- corre `flutter test --no-pub test/widget_test.dart` antes da build

## Instalar no iPhone 12 Pro

Depois de a build aparecer no `App Store Connect` / `TestFlight`:

1. instalar a app `TestFlight` no iPhone
2. aceitar o convite do tester interno ou externo
3. instalar a build
4. validar no equipamento real:
   - login
   - navegacao principal
   - leitura de QR
   - anexar fotografia
   - gravacao de nota audio

## Nota importante sobre auth

Neste projeto, os links de confirmacao / recuperacao por email continuam a
usar o callback web:

`https://cmmscompinta.netlify.app/`

Isto significa que a autenticacao por email funciona, mas esses links nao estao
hoje configurados para reabrir diretamente a app iOS nativa. Para a primeira
entrega iOS isso nao bloqueia login normal nem testes de operacao, mas fica
como melhoria propria se quiseres um fluxo 100% nativo.

## O que precisas no Mac

- macOS com `Xcode`
- conta no `Apple Developer Program`
- acesso ao `App Store Connect`
- `CocoaPods` instalado

## Primeiro arranque no Mac

Na raiz do projeto:

```bash
bash scripts/prepare_ios_on_mac.sh
```

Isto faz:

1. `flutter pub get`
2. limpa `Pods` antigos
3. `pod install`
4. abre `ios/Runner.xcworkspace`

Se depois de configurar o signing quiseres arrancar logo a app em debug:

```bash
bash scripts/run_ios_debug_on_mac.sh
```

Isto faz:

1. `flutter pub get`
2. `pod install`
3. mostra os dispositivos detetados
4. lança `flutter run`

## Configuracao no Xcode

Com o workspace aberto:

1. selecionar target `Runner`
2. abrir `Signing & Capabilities`
3. escolher a tua `Team`
4. confirmar o `Bundle Identifier`:

`com.micaelcunha.mantra`

5. garantir que o signing automatico esta ativo
6. ligar o iPhone por cabo ou selecionar um simulador
7. fazer uma primeira execucao da app antes de arquivar

## Primeira validacao no iPhone

Antes de pensar em TestFlight, valida no dispositivo:

1. abrir login
2. entrar com uma conta real
3. abrir `Ordens`
4. testar leitura de QR
5. testar anexar fotografia
6. confirmar que a navegacao principal abre sem erros

Se esta validacao falhar, corrige primeiro no Xcode e volta a correr localmente.

## App Store Connect

Antes do upload:

1. criar a app no `App Store Connect`
2. usar o mesmo `Bundle ID`
3. definir nome da app, idioma principal e `SKU`
4. preencher informacao minima da app e privacidade

## Build para TestFlight

Opcao mais segura para a primeira vez:

1. `Product` > `Archive`
2. quando o archive abrir no Organizer, escolher `Distribute App`
3. escolher `App Store Connect`
4. escolher `Upload`
5. depois distribuir a build via `TestFlight`

## Testers

Em iOS, os testers usam a app `TestFlight`.

- testers internos: membros da equipa no App Store Connect
- testers externos: por email ou link publico, apos aprovacao beta quando
  aplicavel

## Notas importantes

- se o teu Apple Developer ja tiver um Bundle ID diferente reservado para esta
  app, ajusta o `Bundle Identifier` antes de criares o registo final no App
  Store Connect
- o projeto foi preparado sem Mac, por isso a primeira validacao real iOS
  continua dependente de abrir no Xcode e correr `pod install`
- com o caminho remoto via `Codemagic`, o Mac local deixa de ser obrigatorio
  para fazer build / upload, mas continua util se mais tarde quiseres depurar
  problemas especificos de iOS no Xcode
