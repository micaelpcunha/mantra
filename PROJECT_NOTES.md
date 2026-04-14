## Sessao 2026-03-29 Preparacao iOS e TestFlight sem Mac
- O projeto iOS foi adiantado ao maximo possivel sem acesso a um Mac
- Ajustes feitos:
  - `ios/Runner/Info.plist` passou a mostrar `Mantra` como nome da app
  - foi adicionada descricao de acesso a fotografias em iOS para anexos de
    imagem
  - o `Bundle ID` da app iOS foi alinhado para `com.micaelcunha.mantra`
  - o target de testes foi alinhado para
    `com.micaelcunha.mantra.RunnerTests`
  - foi criado `ios/Podfile`
  - `ios/Flutter/Debug.xcconfig` e `ios/Flutter/Release.xcconfig` passaram a
    incluir as configuracoes de Pods
  - foi criado `scripts/prepare_ios_on_mac.sh` para primeiro arranque no Mac
  - foi criado `IOS_TESTFLIGHT_SETUP.md` com o fluxo de TestFlight
- Objetivo destes ajustes:
  - reduzir o trabalho manual quando o projeto for aberto no Xcode
  - evitar que o wrapper iOS continue com placeholders `com.example.*`
  - deixar o repositorio mais proximo de um primeiro archive para TestFlight
- Validacao:
  - confirmados os novos identificadores em
    `ios/Runner.xcodeproj/project.pbxproj`
  - confirmada a presenca do `Podfile` e do script de arranque iOS no Mac
  - continua sem validacao real de build/archive iOS por falta de Mac/Xcode

## Sessao 2026-03-29 Preparacao Firebase App Distribution
- Foi preparado um fluxo local para distribuir a app Android de teste via
  Firebase App Distribution sem publicar na Play Store
- Novos ficheiros:
  - `deploy_android_firebase.bat`
  - `scripts/deploy_android_firebase.ps1`
  - `scripts/firebase_app_distribution.local.example.ps1`
  - `FIREBASE_APP_DISTRIBUTION_SETUP.md`
- O fluxo foi desenhado para usar configuracao local fora do codigo com:
  - `FIREBASE_APP_ID`
  - `FIREBASE_TOKEN` ou `GOOGLE_APPLICATION_CREDENTIALS`
  - `FIREBASE_TESTERS` e/ou `FIREBASE_GROUPS`
- O `.gitignore` passou a proteger a configuracao local do Firebase App
  Distribution e o cache do `npm`
- O `README.md` passou a documentar o fluxo beta Android
- Validacao:
  - `scripts/deploy_android_firebase.ps1 -SkipDistribute` executado com sucesso
  - `flutter build apk --release` executado com sucesso dentro do novo script
  - APK release validada em `build/app/outputs/flutter-apk/app-release.apk`
  - primeira release Android criada com sucesso no Firebase App Distribution
  - a distribuicao automatica inicial falhou por o grupo `equipa-android`
    ainda nao existir; a configuracao local foi ajustada para usar apenas o
    tester individual ate os grupos ficarem preparados

## Sessao 2026-03-29 Automatizacao do Deploy Web Netlify
- Foi preparada automacao local para atualizar a app web sem depender de
  upload manual da pasta `build/web`
- Novos ficheiros:
  - `deploy_web_netlify.bat`
  - `scripts/deploy_web_netlify.ps1`
  - `scripts/netlify.local.example.ps1`
  - `netlify.toml`
  - `web/_redirects`
- O novo fluxo permite:
  - gerar a build web e publicar para producao na Netlify com um unico comando
  - gerar deploy draft com `-Draft`
  - gerar apenas a build com `-SkipDeploy`
- Os segredos de deploy passaram a ficar fora do codigo via
  `NETLIFY_AUTH_TOKEN` e `NETLIFY_SITE_ID`, com `scripts/netlify.local.ps1`
  ignorado no `.gitignore`
- O `web/_redirects` e o `netlify.toml` garantem comportamento correto de SPA
  na Netlify
- `README.md` foi atualizado com os passos operacionais do novo fluxo
- Validacao:
  - `scripts/deploy_web_netlify.ps1 -SkipDeploy` executado com sucesso
  - `flutter build web` executado com sucesso dentro do novo script
  - `build/web/_redirects` confirmado na build final
  - deploy de producao executado com sucesso para
    `https://cmmscompinta.netlify.app/`

## Sessao 2026-03-29 Fotografia e Obrigatoriedade por Passo
- Os procedimentos passaram a permitir configurar cada passo com duas regras
  proprias:
  - passo obrigatorio ou opcional
  - passo com fotografia propria
- `lib/procedure_templates_page.dart` passou a expor estas opcoes no editor dos
  procedimentos e a mostralas no resumo dos templates
- `lib/models/procedure_template.dart` passou a guardar `is_required`,
  `requires_photo` e `photo_url` dentro do JSON dos passos
- `lib/work_orders/task_detail_page.dart` passou a permitir carregar fotografia
  por passo durante a execucao e passou a bloquear a conclusao da ordem quando
  faltam passos obrigatorios ou fotografias obrigatorias desses passos
- `lib/work_orders/add_work_order_page.dart` passou a validar essa regra quando
  uma ordem e gravada diretamente como `concluido` e a mostrar no resumo da
  ordem quantos passos sao obrigatorios e quantos pedem fotografia
- Validacao:
  - `dart.exe format` executado com sucesso nos ficheiros alterados
  - `flutter build apk --debug` executado com sucesso em 2026-03-29, mantendo a
    APK em `build/app/outputs/flutter-apk/app-debug.apk`

## Sessao 2026-03-29 Procedimentos nas Ordens de Trabalho
- Foi criada a base para procedimentos reutilizaveis associados a ordens de
  trabalho
- Novo script SQL:
  - `SUPABASE_WORK_ORDER_PROCEDURES.sql`
- O script adiciona:
  - tabela `procedure_templates`
  - colunas `procedure_template_id`, `procedure_name` e `procedure_steps` em
    `work_orders`
  - RLS para gestao admin e leitura por admins/tecnicos com acesso a ordens
- Flutter:
  - nova pagina `lib/procedure_templates_page.dart` para gerir procedimentos em
    `Definicoes`
  - `lib/settings_page.dart` e `lib/home_page.dart` passaram a expor a secao
    `Procedimentos`
  - `lib/work_orders/add_work_order_page.dart` passou a permitir escolher um
    procedimento ao criar/editar uma ordem
  - o procedimento fica guardado como snapshot na ordem para nao mudar o
    historico quando o template for alterado ou apagado depois
  - `lib/work_orders/task_detail_page.dart` passou a mostrar o checklist da
    ordem e a persistir os checks
  - ordens preventivas recorrentes passam a copiar o procedimento para a
    proxima ordem com os checks reiniciados
- Ajuste visual adicional:
  - `Resumo Operacional` ficou com maiusculas em `lib/dashboard_page.dart`
- Validacao:
  - `SUPABASE_WORK_ORDER_PROCEDURES.sql` aplicado com sucesso no projeto
    Supabase `uaupakkizxmwgcfrtnnz`
  - `C:\Users\pinta\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format`
    executado com sucesso nos ficheiros alterados
  - `flutter build apk --debug` executado com sucesso em 2026-03-29, gerando
    `build/app/outputs/flutter-apk/app-debug.apk`
  - a validacao por `dart analyze` continua limitada neste ambiente por
    `CreateFile failed 5 (Acesso negado)`

## Sessao 2026-03-29 Confirmacao de Autorizacoes no Planeamento
- `lib/calendar_page.dart` passou a pedir confirmacao explicita dos ativos com
  email configurado antes de abrir a pre-visualizacao das autorizacoes
- A confirmacao aparece numa janela com `checkbox` por ativo e selecao total,
  para o admin decidir exatamente quais os ativos que entram nesse passo
- Depois dessa confirmacao, o calendario passa a assinalar o dia com aviso
  visivel de que ja houve autorizacoes confirmadas
- Sempre que uma ordem relevante desse dia e alterada depois disso
  (remarcacao por calendario ou edicao da ordem com impacto no resumo do email),
  aparece alerta a informar que nao existe novo envio automatico
- Objetivo:
  - evitar enviar/preparar autorizacoes para ativos errados
  - deixar claro que mexer no planeamento depois da confirmacao exige revisao
    manual das autorizacoes
- Validacao:
  - `C:\Users\pinta\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\calendar_page.dart`
    executado com sucesso
  - `dart analyze lib\calendar_page.dart` continuou bloqueado neste ambiente com
    `CreateFile failed 5 (Acesso negado)`

## Sessao 2026-03-29 Fecho de Sessao e Ponto de Retoma
- Ficou registado o estado desta sessao para retomarmos sem perder contexto
- Backend OAuth Google:
  - `email-provider-start` e `email-provider-callback` foram republicadas no
    projeto Supabase `uaupakkizxmwgcfrtnnz`
  - o bloqueio anterior `401 Invalid JWT` ficou corrigido com
    `verify_jwt = false` em `supabase/config.toml`
  - validacao tecnica feita:
    - o callback publico deixou de devolver `401` e passou a entrar na logica
      da function
    - o endpoint de arranque deixou de ser bloqueado pelo gateway e respondeu
      com `Missing Authorization header.` quando testado sem sessao, o que
      confirma que a autenticacao passou a ser tratada pela propria function
- App Flutter:
  - `lib/services/email_provider_auth_service.dart` passou a mostrar mensagem
    operacional mais clara quando houver erro de auth nas Edge Functions
- Segredos locais protegidos:
  - `android/key.properties`, keystores Android e `supabase/.env.local`
    ficaram cobertos pelo `.gitignore`
  - as credenciais Google OAuth ficaram guardadas localmente em
    `supabase/.env.local`
- Ponto exato em que a sessao ficou:
  - o telemovel Android `ec6465ee` foi detetado com sucesso por `adb` e
    `flutter devices`
  - a build `flutter build apk --debug` foi retomada para gerar APK atualizada
    mas a execucao foi interrompida antes de concluir
- Proximo passo ao retomar:
  - correr novamente `flutter build apk --debug`
  - instalar `build/app/outputs/flutter-apk/app-debug.apk` no dispositivo
    `ec6465ee`
  - abrir `Dados da empresa` > `Email de autorizacoes` e testar de novo
    `Ligar Google / Gmail`

## Sessao 2026-03-29 Protecao de Credenciais OAuth Google
- Foi criado um ficheiro local ignorado pelo Git para guardar credenciais
  Google OAuth necessarias ao backend Supabase:
  - `supabase/.env.local`
- O `.gitignore` passou tambem a proteger segredos locais do Supabase:
  - `supabase/.env.local`
  - `supabase/*.local.env`
- Objetivo:
  - manter o `client id` e o `client secret` acessiveis nesta maquina sem os
    espalhar por notas ou ficheiros versionados
- Nota:
  - os nomes das variaveis ficaram alinhados com as Edge Functions:
    `GOOGLE_OAUTH_CLIENT_ID` e `GOOGLE_OAUTH_CLIENT_SECRET`

## Sessao 2026-03-29 Protecao de Segredos Android
- Foi confirmado que a configuracao local de assinatura Android continua
  guardada em `android/key.properties`
- O `.gitignore` foi endurecido para evitar commits acidentais de segredos
  locais de release:
  - `android/key.properties`
  - `android/*.jks`
  - `android/*.keystore`
- Objetivo:
  - proteger passwords e keystores locais sem mexer no template publico
    `android/key.properties.example`
- Validacao:
  - o template sanitizado manteve-se no repositorio
  - os segredos locais ficam agora cobertos por ignore explicito

## Sessao 2026-03-28 Correcao JWT das Edge Functions OAuth
- O erro `401 Invalid JWT` ao carregar `Ligar Google / Gmail` ficou alinhado
  com a configuracao real necessaria das Edge Functions OAuth no Supabase
- Foi criado `supabase/config.toml` com:
  - `functions.email-provider-start.verify_jwt = false`
  - `functions.email-provider-callback.verify_jwt = false`
- Motivo:
  - `email-provider-start` ja valida o admin dentro da propria function
  - `email-provider-callback` precisa de aceitar o redirect publico do
    Google / Microsoft
  - isto evita o bloqueio do `verify_jwt` legado com `401 Invalid JWT`
- `lib/services/email_provider_auth_service.dart` passou a traduzir esse erro
  para uma mensagem operacional mais clara na app
- Documentacao afinada em:
  - `supabase/functions/README.md`
  - `EMAIL_PROVIDER_OAUTH_SETUP.md`
- Validacao pendente:
  - voltar a fazer deploy das functions para o projeto Supabase
  - retestar a ligacao Google / Gmail na app Android

## Sessao 2026-03-27 Hardening e Estabilidade
- `lib/services/storage_service.dart` endurecido com:
  - compressao consistente de fotos ate 1 MB
  - limite de 10 MB para anexos e documentos
  - `contentType` explicito no upload
  - sanitizacao de nomes de ficheiros mais robusta
- `lib/login_page.dart` melhorado com:
  - validacao de email
  - validacao de campos vazios
  - submissao mais previsivel com teclado
- `lib/company_settings_page.dart` ganhou validacao do email remetente
- `lib/calendar_page.dart` mais resiliente:
  - pre-visualizacao de emails ja nao falha se `company_profile` nao estiver acessivel
  - mensagem explicita quando o planeamento nao encontra ativos com email configurado
- `lib/settings_page.dart` passou a indicar de forma mais clara que a configuracao global dos emails de intervencao vive em `Empresa`
- `lib/notes_page.dart` corrigido para reordenacao de blocos funcionar melhor no web
  - a lista reordenavel deixou de estar aninhada dentro de outra `ListView`
  - `RefreshIndicator` foi removido do editor para evitar conflito com drag vertical
  - a pega de arrastar passou a ser uma zona maior com instrucoes visiveis
  - reordenacao mudou para drag manual com `LongPressDraggable` + `DragTarget` entre blocos

## Sessao 2026-03-27 Email de Autorizacao de Entrada
- `assets` recebeu suporte para:
  - `entry_authorization_email`
  - `entry_authorization_subject`
  - `entry_authorization_template`
- Formulario do ativo em `lib/assets_pages.dart` atualizado com:
  - email de autorizacao
  - assunto por defeito
  - texto base do email
- Validacao simples de email adicionada no formulario
- Objetivo: preparar o envio de pedidos de autorizacao de entrada apos planeamento
- `company_profile` preparado para configuracao global de envio:
  - `authorization_email_send_mode`
  - `authorization_email_signature`
  - `authorization_sender_email`
- `lib/company_settings_page.dart` atualizado com secao de:
  - modo manual ou automatico
  - email remetente visivel
  - assinatura global
- `lib/calendar_page.dart` passou a gerar pre-visualizacao de emails de intervencao apos o planeamento
- Emails sao agrupados por ativo e usam:
  - destinatario do ativo
  - assunto do ativo
  - texto base do ativo
  - assinatura global da empresa
  - data da intervencao e tecnico como tokens dinamicos

## Sessao 2026-03-27 Calendario Planeamento
- O fluxo de `Planear dia` deixou de usar `showDialog`
- Nova pagina dedicada em `lib/calendar_page.dart` para selecionar:
  - tecnico
  - ativos
  - ordens por ativo
- Subpagina adicional para escolher ordens dentro de cada ativo
- Fluxo mantem retorno a lista de ativos para adicionar mais ordens antes de confirmar
- Objetivo da alteracao: resolver o overlay escuro/bloqueio no web ao abrir o planeamento

## Sessao 2026-03-27 Notas Pessoais
- Nova aba `Notas` adicionada ao `home_page` para administrador e tecnico
- Nova pagina `lib/notes_page.dart` com:
  - lista de notas por utilizador
  - titulo e corpo de texto editaveis
  - imagens visiveis dentro da nota
  - criacao, edicao e remocao de notas
  - pre-visualizacao e partilha em PDF
- Novo modelo `lib/models/app_note.dart`
- Novo servico `lib/services/note_service.dart`
- `StorageService` estendido para bucket privado `note-images`
- SQL de setup criado em `SUPABASE_NOTES_SETUP.sql` para:
  - tabela `public.notes`
  - RLS por utilizador autenticado nao cliente
  - bucket privado `note-images`
  - policies de storage por pasta do proprio utilizador

# Project Notes

## Projeto
- Nome: `asset_app`
- Produto: CMMS com portal interno e acesso de cliente
- Stack: Flutter + Supabase

## Estado Atual
- App web publicada na Netlify
- URL atual: `https://cmmscompinta.netlify.app/`
- Supabase auth configurado para esse domínio
- Build web já validada com sucesso

## Funcionalidades Já Feitas
- Login/logout com listener de auth
- Gestão de ativos
- Gestão de localizações
- Gestão de ordens de trabalho
- Gestão de técnicos
- Gestão de utilizadores
- Gestão de empresa
- Upload de fotos e anexos
- QR code nos ativos
- Validação QR em manutenção
- Calendário com planeamento
- Relatórios base
- Acesso tipo cliente com visibilidade limitada

## Segurança / RLS
- RLS ativado nas tabelas principais
- Policies aplicadas para:
  - `profiles`
  - `assets`
  - `locations`
  - `work_orders`
  - `technicians`
  - `company_profile`
- Funções auxiliares criadas para controlo de role, permissões e âmbito do cliente

## Regras de Cliente
- Cliente só vê o que está atribuído
- Suporte para:
  - `client_asset_ids`
  - `client_location_ids`
- Flags de visibilidade do cliente já suportadas no perfil

## Ordens de Trabalho
- Tipos suportados:
  - `corretiva`
  - `preventiva`
  - `medicoes_verificacoes`
- `preventiva`:
  - pode repetir automaticamente
  - pode exigir fotografia
  - pode exigir medição
- `medicoes_verificacoes`:
  - pode exigir fotografia
  - pode exigir medição
- Ativos já suportam `default_technician_id`
- Nova ordem pode vir pré-preenchida com o técnico predefinido do ativo

## Relatórios
- Página de relatórios criada
- Filtros por:
  - período
  - estado
  - tipo
  - técnico
  - localização
- KPIs gerais
- KPI próprio para `medicoes_verificacoes`
- Rankings por técnico, localização e ativos
- Indicadores de qualidade de dados

## UI / UX
- Refresh visual suave já aplicado
- Tema global suavizado
- Sidebar mais confortável visualmente
- Scrollbar lateral visível
- Overflow dos filtros dos relatórios corrigido
- Overflow do modal de planeamento corrigido

## Deploy
- Web:
  - build com `flutter build web`
  - deploy manual na Netlify concluído
- Supabase:
  - `Site URL` e `Redirect URLs` atualizados para Netlify

## Links Importantes
- Netlify app: `https://cmmscompinta.netlify.app/`
- Android Studio: `https://developer.android.com/studio`

## Pendente / Próximos Passos
- Automatizar deploy com GitHub
- Ligar domínio próprio
- Hardening opcional de tabelas secundárias no Supabase
- Rever permissões de storage/buckets
- Criar versão Android

## Mobile Android
- Android Studio instalado
- Android SDK confirmado em `C:\Users\pinta\AppData\Local\Android\Sdk`
- Build APK release funcional
- APK disponível em:
  - `build\app\outputs\flutter-apk\app-release.apk`
- A release atual continua a usar a debug key:
  - `signingConfig = signingConfigs.getByName("debug")`
- Isto serve para testes e instalação manual, mas não é ainda a configuração final para publicação oficial

## Sessão 2026-03-25 Android
- Android Studio confirmado em `C:\Program Files\Android\Android Studio`
- Android SDK confirmado em `C:\Users\pinta\AppData\Local\Android\Sdk`
- `cmdline-tools` instalados com sucesso em:
  - `C:\Users\pinta\AppData\Local\Android\Sdk\cmdline-tools\latest\bin`
- Licenças Android aceites com `sdkmanager --licenses`
- Durante a primeira build, o sistema instalou automaticamente componentes em falta:
  - `NDK (Side by side) 28.2.13676358`
  - `Android SDK Build-Tools 35.0.0`
  - `Android SDK Platform 36`
  - `Android SDK Platform 34`
  - `CMake 3.22.1`
- Foi necessário limpar lockfiles stale do Flutter em:
  - `C:\Users\pinta\develop\flutter\bin\cache\lockfile`
  - `C:\Users\pinta\develop\flutter\bin\cache\flutter.bat.lock`
- Build Android concluída com sucesso
- APK release gerado em:
  - `build\app\outputs\flutter-apk\app-release.apk`
- Tamanho aproximado do APK:
  - `69.9 MB`
- Warnings não bloqueantes no fim da build:
  - Java `source value 8` e `target value 8` obsoletos

## Sessão 2026-03-26 Android e Layout Mobile
- Build APK release repetida com sucesso a partir do estado atual do projeto
- APK testada num dispositivo Android real com instalação manual
- Dispositivo físico confirmado no Flutter:
  - `2112123AG (mobile)`
  - `device id: ec6465ee`
- Foi validado que o fluxo de desenvolvimento pode continuar com `flutter run -d ec6465ee`
- Não foi configurado `keystore` de release final nesta fase, por não ser necessário para testes em dispositivo físico

## Sessão 2026-03-26 Ajustes Mobile Admin
- Dashboard mobile compactado em `lib/dashboard_page.dart`
- Redução de padding geral no dashboard mobile
- Cartões KPI (`Ativos`, `Localizações`, `Ordens em aberto`, `Alertas`) reorganizados para caberem em 2 colunas no topo
- Cartão `Visão geral` removido no mobile e substituído por botão direto `Nova ordem`
- Os quatro cartões KPI passaram a ser clicáveis e a abrir o ecrã respetivo
- Menu inferior mobile alterado em `lib/home_page.dart`
- A `NavigationBar` nativa foi substituída por uma barra horizontal com scroll
- Os itens do menu inferior ficaram com largura uniforme e texto mais consistente
- Foi adicionado hint visual de scroll horizontal:
  - fade lateral
  - seta no lado direito

## Próximo Passo Recomendado
- Continuar a revisão mobile da vista de administrador, ecrã a ecrã, usando o telemóvel físico ligado por USB
- Próxima área natural para rever depois do dashboard:
  - `Ativos`
  - `Localizações`
  - `Ordens de trabalho`
  - `Alertas`

## Nota de Continuidade
- Quando retomarmos o projeto, pedir para ler este ficheiro primeiro:
  - `PROJECT_NOTES.md`
- Continuar a guardar aqui o resumo de cada sessão importante

## Regra de Trabalho
- Atualizar `PROJECT_NOTES.md` a cada 10 minutos de utilização continuada ou no fim de cada sessão importante
- Se houver várias alterações relevantes antes dos 10 minutos, resumir tudo na mesma atualização

## Sessao 2026-03-27 Hardening Seguranca
- Revisao de seguranca iniciada com foco em impedir que tecnicos contornem permissoes apenas por alteracao da app cliente
- Em `lib/services/profile_service.dart` foi removido o fallback permissivo por `userMetadata` / `appMetadata`
- O perfil atual passou a depender de `profiles` como fonte autoritativa
- Em `lib/home_page.dart` a simulacao de role passou a ficar limitada a admin
- Em `android/app/src/main/AndroidManifest.xml` foi definido `android:allowBackup="false"`
- Foi criado `SUPABASE_SECURITY_CHECKLIST.md` com checklist operacional para auditoria de RLS, policies e storage
- Foi criado `SUPABASE_SECURITY_HARDENING.sql` como draft de hardening do Supabase alinhado com o codigo da app
- No Supabase, `RLS` ficou confirmado como ativo em:
  - `profiles`
  - `technicians`
  - `assets`
  - `locations`
  - `work_orders`
  - `company_profile`
  - `admin_notifications`
- Policies antigas e redundantes foram removidas e ficou apenas o conjunto novo nas tabelas criticas
- `technician-documents` foi alterado para privado
- `work-order-attachments` foi alterado para privado
- Em `lib/services/storage_service.dart` foi adicionado suporte a signed URLs para buckets privados
- Em:
  - `lib/technicians_page.dart`
  - `lib/work_orders/add_work_order_page.dart`
  - `lib/work_orders/task_detail_page.dart`
  o acesso a documentos/anexos privados passou a usar signed URLs
- Nesta fase:
  - `company-media` ficou publico por decisao consciente para nao partir logo/capa da empresa
  - os buckets de fotos continuam publicos por simplicidade operacional temporaria
- Estado atual:
  - backend principal bastante mais fechado
  - tecnicos deixam de depender de permissoes apenas na UI
  - documentos de tecnico e anexos de ordens deixaram de depender de URLs publicas
- Proximos passos naturais quando retomarmos:
  - validar no telemovel se anexos e documentos privados continuam a abrir corretamente
  - decidir se `company-media` tambem deve passar para privado
  - decidir se as fotos tambem devem passar para buckets privados
  - configurar assinatura `release` Android final

## Sessao 2026-03-28 Direcao Produto Multiempresa
- A direcao do projeto mudou de app feita a medida para produto com potencial de negocio
- Foi confirmada a necessidade de orientar a app para:
  - publicacao futura na Play Store
  - isolamento multiempresa
  - personalizacao por empresa
  - evolucao para onboarding e configuracao mais autonomos
- Analise ao estado atual concluiu que a app ainda esta maioritariamente em modelo single-tenant:
  - seguranca baseada em `auth.uid()` e `role`
  - `company_profile` ainda tratado como registo unico
  - sem sistema generico de campos personalizados
  - branding/publicacao ainda com placeholders tecnicos (`asset_app`, `com.example.asset_app`, signing debug)
- Foi criado `SUPABASE_PRODUCT_FOUNDATION.sql` como draft aditivo para iniciar:
  - tabela `companies`
  - coluna `company_id` nas tabelas principais
  - helpers SQL para futura migracao de RLS por empresa
  - tabelas `custom_field_definitions` e `custom_field_values`
- O codigo Dart ficou preparado para a transicao:
  - modelos principais passaram a aceitar `company_id`
  - `CompanyService` passou a tentar resolver `company_id` do utilizador atual
  - `CompanyService` usa fallback para o comportamento legacy enquanto a base de dados nao estiver migrada
- Proximo passo recomendado:
  - aplicar e rever a fundacao multiempresa no Supabase de desenvolvimento
  - depois migrar RLS e queries principais para escopo por `company_id`

## Sessao 2026-03-28 Passo Seguinte Multiempresa
- Foi criado `lib/services/company_scope_service.dart` para resolver `company_id` do utilizador autenticado e anexar esse valor aos payloads apenas quando a tabela e a base de dados ja suportam a coluna
- O helper foi ligado aos principais fluxos de escrita:
  - `profiles`
  - `assets`
  - `locations`
  - `technicians`
  - `work_orders`
  - `notes`
  - `admin_notifications`
  - `company_profile`
- A compatibilidade com o schema antigo foi mantida:
  - se `company_id` ainda nao existir na base de dados, os inserts continuam a funcionar sem essa coluna
- `SUPABASE_PRODUCT_FOUNDATION.sql` passou tambem a prever triggers para auto-preencher `company_id` no backend quando a migracao multiempresa estiver aplicada
- Foi criado `SUPABASE_MULTITENANT_RLS.sql` como draft para a fase seguinte de isolamento:
  - policies de RLS reescritas com `company_id`
  - isolamento por empresa mantido em conjunto com o modelo atual de roles/permissoes
  - `admin_notifications` ajustado para refletir melhor o comportamento real da app, permitindo criacao por tecnicos quando editam/fecham ordens
- Foi criado `SUPABASE_MULTITENANT_VALIDATION.sql` para validar:
  - existencia das novas tabelas/colunas
  - preenchimento de `company_id`
  - triggers de auto-preenchimento
  - policies esperadas
  - buckets relevantes
- Foi criado `SUPABASE_MIGRATION_RUNBOOK.md` com a ordem curta de execucao no SQL Editor e smoke test apos migracao
- Proximo passo recomendado:
  - aplicar `SUPABASE_PRODUCT_FOUNDATION.sql`
  - correr `SUPABASE_MULTITENANT_VALIDATION.sql`
  - depois aplicar e testar `SUPABASE_MULTITENANT_RLS.sql`
  - voltar a correr `SUPABASE_MULTITENANT_VALIDATION.sql`
  - validar login, lista de ativos, ordens, utilizadores e criacao/edicao em ambiente de desenvolvimento

## Sessao 2026-03-28 Execucao Manual Supabase Multiempresa
- O utilizador comecou a aplicar a migracao multiempresa manualmente no SQL Editor do Supabase
- Durante a execucao real apareceram incompatibilidades com o schema existente:
  - `public.companies` ja existia mas estava incompleta
  - faltavam colunas como `slug` e `display_name`
  - algumas tabelas principais ainda nao tinham `company_id`
- `SUPABASE_PRODUCT_FOUNDATION.sql` foi ajustado para ficar mais resiliente:
  - passou a usar `alter table ... add column if not exists` para completar `public.companies`
  - `current_user_company_id()` deixou de depender de `current_user_profile()` e passou a ler diretamente de `public.profiles`
- Estado confirmado no Supabase neste ponto:
  - `company_id` ja existe em:
    - `profiles`
    - `technicians`
    - `assets`
    - `locations`
    - `work_orders`
    - `company_profile`
  - os dados legacy ainda estavam por preencher com `company_id`
  - contagem observada antes do backfill:
    - `assets`: 5 rows, 5 sem `company_id`
    - `company_profile`: 1 row, 1 sem `company_id`
    - `locations`: 3 rows, 3 sem `company_id`
    - `profiles`: 1 row, 1 sem `company_id`
    - `technicians`: 3 rows, 3 sem `company_id`
    - `work_orders`: 9 rows, 9 sem `company_id`
- O proximo passo exato em que a sessao ficou em pausa foi correr no SQL Editor um `do $$ ... $$;` para:
  - obter a `default_company_id` de `public.companies`
  - preencher `company_id` nas tabelas legacy acima
- Nota de colaboracao:
  - o utilizador pediu explicitamente para avancarmos passo a passo, com apenas um passo por vez
  - ao retomar, continuar exatamente desse backfill e so depois repetir a validacao de `missing_company_id`

## Sessao 2026-03-28 Continuacao Execucao Manual Supabase Multiempresa
- O backfill manual de `company_id` foi concluido com sucesso no Supabase
- A `default_company_id` usada no backfill ficou:
  - `198ea8d8-9258-44c6-baac-427c533cd573`
- Registos atualizados no backfill manual:
  - `profiles`: 1
  - `technicians`: 3
  - `assets`: 5
  - `locations`: 3
  - `work_orders`: 9
  - `company_profile`: 1
- A validacao de `missing_company_id` ficou limpa apos o backfill:
  - `assets`: 0
  - `company_profile`: 0
  - `locations`: 0
  - `profiles`: 0
  - `technicians`: 0
  - `work_orders`: 0
- `SUPABASE_MULTITENANT_RLS.sql` foi alinhado com a correcao ja feita na fundacao:
  - `current_user_company_id()` voltou a ler diretamente de `public.profiles`
  - objetivo: evitar reintroduzir a dependencia antiga de `current_user_profile()` para resolver `company_id`
- Durante a aplicacao real do RLS surgiram incompatibilidades com o schema atual do Supabase:
  - `current_user_technician_id()` ja existia com tipo de retorno compativel com `uuid`
  - `client_asset_ids` e `client_location_ids` estavam em `uuid[]` e nao em `text[]`
- `SUPABASE_MULTITENANT_RLS.sql` foi ajustado para refletir o schema real:
  - `current_user_technician_id()` passou a devolver `uuid`
  - comparacoes com `technician_id` deixaram de usar cast para `text`
  - comparacoes de ambito do cliente passaram a usar `uuid[]`
- `SUPABASE_MULTITENANT_RLS.sql` foi aplicado com sucesso no Supabase apos esses ajustes
- Proximo passo recomendado:
  - correr novamente `SUPABASE_MULTITENANT_VALIDATION.sql`
  - se a validacao ficar limpa, avancar para smoke test na app

## Sessao 2026-03-28 Validacao Pos-RLS
- A reaplicacao de `SUPABASE_MULTITENANT_VALIDATION.sql` avancou ate ao bloco de custom fields
- A validacao falhou em:
  - `public.custom_field_definitions` inexistente
- Isto confirmou que a parte final de personalizacao de produto da fundacao nao ficou materializada no Supabase atual
- As tabelas em falta foram depois criadas com sucesso:
  - `public.custom_field_definitions`
  - `public.custom_field_values`
- A validacao completa foi depois repetida sem erros bloqueantes
- Os buckets sensiveis ficaram confirmados como privados:
  - `work-order-attachments`
  - `technician-documents`
  - `note-images`
- Foi tambem observado que `company-media` esta privado neste ambiente
- Proximo passo recomendado:
  - avancar para smoke test na app
  - validar login e fluxos principais com admin, tecnico e cliente

## Sessao 2026-03-28 Ligacao Direta e Smoke Test Inicial
- Foi configurada ligacao direta por `psql` a partir desta maquina ao projeto Supabase
- A ligacao foi testada com sucesso ao projeto:
  - `uaupakkizxmwgcfrtnnz`
- No smoke test da app:
  - login `admin` confirmado sem erro
  - abertura das areas principais confirmada sem erro
  - `Ativos` e `Empresa` abriram corretamente
- Proximo passo recomendado:
  - validar conta `tecnico`
  - confirmar que nao ganha acesso indevido a areas de administracao

## Sessao 2026-03-28 Auditoria Produto Multiempresa
- Foi feita uma auditoria direta ao Supabase com `psql` depois da migracao multiempresa
- Estado confirmado no ambiente remoto:
  - `admin_notifications` com RLS ativo
  - `notes` com RLS ativo
  - `companies` ainda sem RLS ativo
  - `custom_field_definitions` ainda sem RLS ativo
  - `custom_field_values` ainda sem RLS ativo
- Foi confirmado que as policies ainda nao existem nessas tres tabelas de produto
- Para fechar esse gap foi preparado localmente:
  - `SUPABASE_PRODUCT_HARDENING.sql`
  - tambem foi alinhado `SUPABASE_MULTITENANT_RLS.sql` para incluir essas tabelas
  - `SUPABASE_MULTITENANT_VALIDATION.sql` passou a verificar tambem essas policies e o estado de RLS
- Melhorias locais feitas na app a pensar em produto multiempresa:
  - `company-media` passou a ser tratado como bucket privado no cliente
  - `CompanyService` passou a fazer fallback de `company_profile` para `companies`
  - guardar `company_profile` passa tambem a sincronizar identidade base em `companies`
  - a pagina de empresa passou a guardar paths de storage e a resolver previews por signed URL
  - o shell principal passou a mostrar o nome da empresa quando existir
  - branding visivel foi tornado mais neutro:
    - `CMMS` como titulo base da app
    - titulo web e manifest ajustados
    - label Android ajustada
    - PDF de relatorios deixou de usar o nome provisório antigo
- Foi tambem corrigido um bug local no `home_page.dart`:
  - a side navigation estava a usar `brandTitle` e `brandSubtitle` dentro de um bloco `const`
  - agora recebe esses valores por parametro
- Risco ainda em aberto:
  - `applicationId`, `namespace` e package Android continuam com placeholder tecnico `com.example.asset_app`
  - isso nao foi alterado ainda para evitar impacto desnecessario no identificador da app sem planeamento
- Proximo passo recomendado:
  - aplicar `SUPABASE_PRODUCT_HARDENING.sql` no ambiente remoto
  - validar novamente `pg_policies` e `relrowsecurity`
  - continuar smoke test com tecnico e cliente

## Sessao 2026-03-28 Hardening Remoto Aplicado
- `SUPABASE_PRODUCT_HARDENING.sql` foi aplicado com sucesso diretamente no projeto Supabase
- Estado confirmado apos aplicacao:
  - `companies` com RLS ativo
  - `custom_field_definitions` com RLS ativo
  - `custom_field_values` com RLS ativo
  - policies criadas para `SELECT`, `INSERT`, `UPDATE` e `DELETE` nas tabelas de custom fields
  - policies criadas para `SELECT`, `UPDATE` e `DELETE` em `companies`
- O gap principal de isolamento de dados ao nivel do produto ficou fechado neste ambiente
- A validacao estatica local por `dart analyze` nao conseguiu correr neste ambiente por erro de permissao do processo:
  - `CreateFile failed 5 (Acesso negado)`
- Foi feita validacao manual das zonas alteradas mais criticas:
  - `home_page.dart` corrigido para passar branding dinamico por parametro na side navigation
  - `main.dart` passou a usar `onGenerateTitle`
  - branding web/Android ajustado para `CMMS`
- Proximo passo recomendado:
  - retomar smoke test com conta `tecnico`
  - validar depois conta `cliente`
  - decidir mais tarde se vale a pena renomear tambem `applicationId` e package Android

## Sessao 2026-03-28 Bloqueio no Teste de Cliente
- O teste de `tecnico` ficou confirmado com sucesso
- Ao tentar preparar o teste de `cliente`, apareceu erro ao gravar o novo utilizador na app:
  - `new row violates row-level security policy (USING expression) for table "profiles"`
- Diagnostico ja confirmado:
  - existe trigger `auth.users -> on_auth_user_created`
  - ao criar o utilizador no Auth, o perfil aparece automaticamente em `public.profiles`
  - esse perfil auto-criado pode ficar sem `company_id`
  - o `upsert` da app entra em caminho de `UPDATE`
  - a policy `profiles_update_admin_only` exige que a linha existente ja pertença a empresa atual
  - por isso o update falha antes de conseguir corrigir `company_id`
- Estado observado no ambiente real para o utilizador de teste:
  - `email`: `cliente@cliente.com`
  - `id`: `694694b1-aac8-4fa9-9aba-67cfc130825f`
  - `role`: `tecnico`
  - `company_id`: `null`
- Proximo passo recomendado ao retomar:
  - corrigir o perfil orfao existente em `public.profiles`
  - ajustar o RLS ou o fluxo de onboarding para permitir que admins atribuam `company_id` a perfis auto-criados com `company_id null`
  - repetir depois o teste de login com conta `cliente`

## Sessao 2026-03-28 Correcao do Onboarding de Cliente
- Foi criada a patch [SUPABASE_CLIENT_ONBOARDING_FIX.sql](/c:/Users/pinta/asset_app/SUPABASE_CLIENT_ONBOARDING_FIX.sql)
- A patch foi aplicada com sucesso no Supabase
- Alteracao feita:
  - a policy `profiles_update_admin_only` passou a permitir `UPDATE` por admin tambem quando a linha existente tem `company_id null`
  - o `WITH CHECK` continua a exigir que o valor final de `company_id` pertença a empresa atual
- Objetivo:
  - permitir que o `upsert` da app consiga reclamar perfis auto-criados por `auth.users` e ainda nao associados a empresa
- Proximo passo recomendado:
  - na app, voltar a carregar em `Guardar utilizador` no formulario do cliente de teste
  - se guardar, fazer logout e testar login com a conta `cliente`

## Sessao 2026-03-28 Smoke Test por Perfil Concluido
- O fluxo de criacao e login do cliente ficou validado com sucesso apos a correcao de onboarding
- Resultado dos smoke tests:
  - `admin` ok
  - `tecnico` ok
  - `cliente` ok
- Comportamento esperado confirmado:
  - login sem erro nos tres perfis
  - `tecnico` sem acesso indevido a areas administrativas
  - `cliente` sem acesso a `Utilizadores`, `Empresa` e areas administrativas
- A migracao multiempresa e o endurecimento principal de RLS ficam validados funcionalmente neste ambiente
- Proximo passo recomendado:
  - avancar para melhorias de produto multiempresa no codigo
  - rever onboarding, branding residual e identificadores tecnicos ainda presentes

## Sessao 2026-03-28 Melhoria de Onboarding de Utilizadores
- `lib/users_page.dart` foi melhorado para reduzir friccao no onboarding de utilizadores
- Mudancas feitas:
  - o campo `ID do utilizador` deixou de ser obrigatorio na pratica para novos perfis
  - ao guardar, a app tenta encontrar automaticamente o perfil pelo email em `public.profiles`
  - foi adicionada uma caixa de ajuda no topo com o fluxo correto:
    - criar conta primeiro em `Supabase Authentication`
    - usar depois o mesmo email na app
    - deixar a app resolver o ID automaticamente quando o perfil ja existir
  - foi adicionada indicacao visual de resolucao automatica do perfil
- Objetivo:
  - reduzir dependencias de copiar manualmente o UUID do `auth.users`
  - tornar a criacao de clientes, tecnicos e admins mais adequada a um produto multiempresa
- Branding tecnico adicional removido:
  - `pubspec.yaml` deixou de usar a descricao placeholder `A new Flutter project.`

## Sessao 2026-03-28 Preparacao para Branding Visual
- `lib/home_page.dart` foi preparado para mostrar o logotipo real da empresa no shell lateral
- O logo passa a ser resolvido via `StorageService.resolveFileUri(...)`
- Isto garante compatibilidade com o bucket `company-media` privado, usando URL assinada quando necessario
- Fallback mantido:
  - se nao existir logo valido, a app continua a mostrar o icon placeholder atual
- Proximo passo recomendado:
  - inserir o logotipo final fornecido pelo utilizador
  - depois rever se faz sentido aplicar tambem branding visual no login e nos relatorios

## Sessao 2026-03-28 Branding Mantra Integrado
- O nome comercial da aplicacao ficou definido como `Mantra`
- O logotipo fornecido pelo utilizador foi integrado no projeto
  - origem: `C:\Users\pinta\OneDrive\mantra\Mantra logo.png`
  - copia local de trabalho: `assets/branding/mantra_logo.png`
  - versao otimizada criada para a app: `assets/branding/mantra_logo.jpg`
- Otimizacao do logo:
  - tamanho original aproximado: `2 080 000` bytes
  - tamanho final usado na app: `18 842` bytes
  - objetivo: reduzir peso sem carregar desnecessariamente o arranque e o bundle
- Branding atualizado no produto:
  - `lib/config/branding.dart` passou a centralizar `productName` e `productLogoAsset`
  - `lib/l10n/app_localizations.dart` passou a usar `Mantra` como titulo da app
  - `pubspec.yaml` passou a incluir o asset do logotipo e descricao de produto
  - `web/index.html`, `web/manifest.json`, `README.md` e `android/app/src/main/AndroidManifest.xml` ficaram alinhados com `Mantra`
  - `lib/home_page.dart` mostra agora o logotipo Mantra no shell principal
- Credito visual discreto:
  - foi colocado no canto inferior direito do shell principal:
    - `created and developed by Micael Cunha`
  - foi mantido pequeno e fora das areas principais de trabalho
- Nota pendente:
  - os identificadores tecnicos `asset_app` e `com.example.asset_app` continuam por decidir, porque a renomeacao tem impacto mais sensivel em build e distribuicao

## Sessao 2026-03-28 Icone e Splash Mantra
- O logotipo fornecido foi reaproveitado para criar assets dedicados de iconografia e arranque
- Foram gerados assets intermédios de trabalho:
  - `assets/branding/mantra_logo_transparent.png`
  - `assets/branding/mantra_mark.png`
- Icone da app:
  - o icone passou a usar apenas o simbolo da marca, em vez da palavra completa
  - foram substituidos os `ic_launcher.png` de Android em todas as densidades
  - foram atualizados tambem `web/favicon.png` e os icons do `web/manifest.json`
- Splash screen:
  - o splash Android passou a usar fundo `#162330`
  - foi ativado o `launch_image` centrado em:
    - `android/app/src/main/res/drawable/launch_background.xml`
    - `android/app/src/main/res/drawable-v21/launch_background.xml`
  - foram gerados `launch_image.png` especificos por densidade com tamanho reduzido para evitar peso excessivo
- Ajuste adicional:
  - `web/index.html` e `web/manifest.json` ficaram alinhados com a mesma cor base da marca para melhor consistencia visual

## Sessao 2026-03-28 Android Branding Nativo
- Foi melhorada a camada nativa Android sem ainda mexer na renomeacao tecnica do package
- Alteracoes aplicadas:
  - `AndroidManifest.xml` passou a declarar tambem `android:roundIcon`
  - foram criados `colors.xml` e `colors-night.xml` com a cor base da marca
  - `NormalTheme` deixou de cair no fundo de sistema e passou a usar fundo de marca para evitar flashes visuais entre splash e Flutter
  - foram adicionados `values-v31/styles.xml` e `values-night-v31/styles.xml` para melhor comportamento em Android 12+
  - foi criado `drawable-nodpi/ic_launcher_foreground.png` para adaptive icon e splash moderno
  - foram adicionados `mipmap-anydpi-v26/ic_launcher.xml` e `ic_launcher_round.xml`
  - foram criados tambem os `ic_launcher_round.png` de fallback para densidades classicas
- Resultado esperado:
  - melhor consistencia visual no arranque em Android moderno
  - launcher icon mais correto em dispositivos com icones adaptativos e redondos
- Nota:
  - a renomeacao tecnica de `com.example.asset_app` fica para o passo seguinte, separado de proposito para reduzir risco
  - foi tentada uma `build apk --debug` para validacao rapida, mas nao devolveu resultado dentro do timeout desta sessao; os recursos nativos foram revistos manualmente e o teste visual em dispositivo continua recomendado

## Sessao 2026-03-28 Renomeacao Tecnica Android
- O identificador tecnico Android passou a ser `com.micaelcunha.mantra`
- Alteracoes aplicadas:
  - `namespace` atualizado em `android/app/build.gradle.kts`
  - `applicationId` atualizado em `android/app/build.gradle.kts`
  - `MainActivity.kt` movido para `android/app/src/main/kotlin/com/micaelcunha/mantra/`
  - `package` Kotlin atualizado para `com.micaelcunha.mantra`
- Nota:
  - esta renomeacao foi limitada a Android, sem alterar ainda o nome tecnico do package Flutter em `pubspec.yaml`
  - apos a renomeacao foram corrigidos tambem detalhes de compatibilidade em `lib/users_page.dart` e nos recursos `values-v31` / `launch_background.xml`
  - a `build apk --debug` concluiu com sucesso depois dessas correcoes
  - a APK `build/app/outputs/flutter-apk/app-debug.apk` foi instalada com sucesso num dispositivo Android ligado por `adb`

## Sessao 2026-03-28 Ajustes em Notas e Revisao do Logo
- A pagina `Notas` foi ajustada para ficar mais adequada a uso tecnico e mobile
- Melhorias aplicadas:
  - `lib/notes_page.dart` passou a distinguir layout compacto
  - em ecras pequenos os blocos podem ser reordenados com setas, sem depender tanto de drag and drop
  - o cabecalho ficou mais simples e orientado a notas pessoais
  - a simulacao de tecnico deixou de mostrar uma experiencia enganadora em `Notas`, porque estas notas pertencem sempre a conta autenticada
  - `lib/home_page.dart` passou a enviar contexto de tecnico/simulacao para a pagina
- O tratamento anterior do logotipo ficou descartado porque a imagem original com blur/fundo nao funcionava bem como marca de app
- Foi criada uma marca limpa para a app:
  - `assets/branding/mantra_mark_clean.png`
  - `assets/branding/mantra_mark_trimmed.png`
- Essa marca limpa passou a ser usada em:
  - `lib/config/branding.dart`
  - `lib/login_page.dart`
  - `lib/home_page.dart`
  - launcher icon Android
  - splash Android
  - favicon e icons web
- A app foi recompilada com sucesso e a APK atualizada voltou a ser instalada no telemovel por `adb`

## Sessao 2026-03-28 Criacao de Tecnicos sem ID Manual
- O fluxo de criacao de tecnicos foi simplificado em `lib/technicians_page.dart`
- Problema anterior:
  - a app exigia preencher manualmente `ID tecnico`
  - isso nao fazia sentido para admins, porque a tabela `public.technicians` ja tem `uuid_generate_v4()` por defeito
- Alteracao aplicada:
  - ao criar um tecnico novo, o ID deixa de ser obrigatorio
  - a app deixa de pedir esse valor e informa que sera gerado automaticamente ao guardar
  - ao editar um tecnico existente, o ID continua visivel apenas em modo de leitura
- Validacao:
  - foi confirmada no Supabase a existencia de `column_default = uuid_generate_v4()` em `public.technicians.id`
  - a app foi recompilada com sucesso
  - a APK atualizada foi instalada no telemovel por `adb`

## Sessao 2026-03-28 Criacao e Eliminacao de Acessos pela App
- Foi implementado um backend seguro no Supabase para o admin gerir acessos sem sair da app
- Novo script:
  - `SUPABASE_MANAGED_ACCOUNT_FLOW.sql`
- Alteracoes de base de dados:
  - reforco de `public.handle_new_user()` para copiar `full_name`, `role`, `company_id` e `technician_id` desde `auth.users.raw_user_meta_data`
  - nova funcao `public.can_manage_user_accounts()`
  - nova funcao `public.can_manage_technician_records()`
  - nova funcao `public.admin_create_auth_user(...)`
  - nova funcao `public.admin_delete_auth_user(...)`
  - nova funcao `public.admin_delete_technician_bundle(...)`
  - o script foi aplicado com sucesso no Supabase
- Flutter:
  - novo servico `lib/services/managed_account_service.dart`
  - `lib/users_page.dart` passou a:
    - criar automaticamente a conta de acesso com email/password quando o email ainda nao existe
    - reaproveitar um perfil ja existente quando o email ja existe
    - permitir eliminar utilizadores diretamente na app
    - eliminar tecnico completo quando o utilizador editado e um tecnico ligado a uma ficha tecnica
  - `lib/technicians_page.dart` passou a:
    - permitir criar tecnico com acesso a app no mesmo fluxo
    - pedir password temporaria no proprio formulario quando o acesso e criado
    - mostrar estado do acesso na ficha do tecnico
    - permitir eliminar o tecnico e o acesso associado em seguranca
    - ao eliminar, as ordens ficam sem `technician_id` para preservar o historico
- Validacao:
  - `flutter build apk --debug` concluiu com sucesso
  - a APK `build/app/outputs/flutter-apk/app-debug.apk` foi instalada com sucesso no telemovel por `adb`

## Sessao 2026-03-28 Correcao do Login de Contas Geridas
- Foi corrigido o erro de login `unexpected_failure / Database error querying schema` nas contas criadas pelo fluxo gerido da app
- Causa:
  - a funcao `public.admin_create_auth_user(...)` estava a gravar `auth.users` e `auth.identities` com alguns campos fora do padrao usado pelo proprio Supabase Auth
- Ajustes aplicados em `SUPABASE_MANAGED_ACCOUNT_FLOW.sql`:
  - password bcrypt passa a ser criada com `gen_salt('bf', 10)`
  - campos de token em `auth.users` passam a ser inicializados com string vazia em vez de `null`
  - `is_super_admin` deixa de ser forzado a `false`
  - `auth.identities.identity_data.email_verified` passa a seguir o formato observado nas contas nativas
- Ajuste adicional:
  - as funcoes de eliminacao deixaram de tentar apagar diretamente linhas em `storage.objects`, porque o Supabase bloqueia esse caminho
  - a limpeza de ficheiros associados fica para um passo futuro via Storage API / backend dedicado
- Validacao:
  - o login do tecnico `tecnico@tecnico.com` voltou a funcionar no endpoint `/auth/v1/token`
  - foi criada uma conta de teste nova via `public.admin_create_auth_user(...)` e o login dessa conta tambem funcionou
  - a conta de teste foi removida de seguida

## Sessao 2026-03-28 Regra de Notas de Projeto
- Foi adicionado `AGENTS.md` na raiz do repositorio para orientar futuras sessoes do Codex
- Nova regra de trabalho:
  - tarefas com alteracoes relevantes devem terminar com atualizacao de `PROJECT_NOTES.md`
  - as notas devem ficar em formato de sessao curta, com tema e validacao quando aplicavel
- Objetivo:
  - manter o historico operacional do projeto consistente entre sessoes sem depender de memoria manual

## Sessao 2026-03-28 Ajuste das Instrucoes do Projeto
- O `AGENTS.md` foi afinado para refletir melhor o modo de trabalho do projeto
- Regras adicionais definidas:
  - respostas ao utilizador por defeito em portugues europeu
  - preferencia por execucao end-to-end em vez de parar na analise
  - alteracoes de Supabase devem ficar refletidas nos scripts SQL do repositorio
  - alteracoes Android orientadas a dispositivo devem incluir `build apk --debug` e `adb install` quando houver equipamento disponivel
  - preferencia por fluxos de admin automatizados quando existirem caminhos seguros de backend
- Objetivo:
  - tornar futuras sessoes mais consistentes com o processo real do projeto

## Sessao 2026-03-28 Fecho de Pendentes Tecnicos
- Foi removida a dependencia da `debug key` na configuracao `release` Android
- `android/app/build.gradle.kts` passou a:
  - carregar assinatura `release` a partir de `android/key.properties`
  - falhar com erro claro quando for pedida uma build `release` sem essa configuracao
- Foi criado `android/key.properties.example` como modelo local para o keystore final
- `README.md` deixou de ter conteudo placeholder e passou a documentar:
  - resumo real do produto
  - scripts Supabase principais
  - fluxo de `release signing` Android
- `lib/services/storage_service.dart` ganhou remocao de ficheiros por bucket/path
- A limpeza de ficheiros associados ficou integrada em:
  - eliminacao de tecnico em `lib/technicians_page.dart`
  - eliminacao de utilizador tecnico em `lib/users_page.dart`
  - rollback de criacao e substituicao de ficheiros no formulario de tecnico
- Objetivo:
  - reduzir orfaos no Supabase Storage e fechar o pendente antigo de limpeza associada
- Validacao conseguida neste ambiente:
  - `dart.exe format lib/services/storage_service.dart lib/users_page.dart lib/technicians_page.dart` executado com sucesso
- Validacao bloqueada neste ambiente:
  - `dart analyze lib test` continuou a falhar com `CreateFile failed 5 (Acesso negado)` ao arrancar o analysis server
  - `flutter` via wrapper ficou bloqueado por processos/lockfiles antigos neste ambiente
  - `gradlew` exigiu contorno de `JAVA_HOME`, mas a validacao final do wrapper ficou limitada pelo cache/distribution do sandbox
- Estado pratico apos esta sessao:
  - a base para `release signing` ficou preparada, faltando apenas o teu keystore real
  - a limpeza de ficheiros de tecnicos/utilizadores ficou implementada no cliente

## Sessao 2026-03-28 Keystore Android de Producao
- Foi gerado um keystore local de producao para Android em:
  - `android/mantra-upload-key.jks`
- Foi criado o ficheiro local:
  - `android/key.properties`
- Configuracao usada:
  - `storeFile = mantra-upload-key.jks`
  - `keyAlias = mantra_upload`
- Validacao:
  - `keytool -list -v` confirmou a entrada `PrivateKeyEntry`
  - certificado emitido para `CN=Mantra, OU=Mobile, O=Mantra, C=PT`
- Nota operacional importante:
  - este keystore e as credenciais locais devem ser guardados em backup seguro fora do projeto antes de qualquer publicacao na Play Store

## Sessao 2026-03-28 Base de Integracao de Email Google e Microsoft
- Foi criada a base de dados e da app para ligacao futura de contas reais de email por empresa
- Novo script `SUPABASE_EMAIL_PROVIDER_FOUNDATION.sql`:
  - adiciona `authorization_email_provider` e `authorization_email_connection_id` a `company_profile`
  - cria `company_email_connections`
  - aplica `default 'manual'` ao provider
  - ativa RLS admin-only por empresa
- Novos modelos/servicos:
  - `lib/models/company_email_connection.dart`
  - `lib/services/company_email_connection_service.dart`
- `lib/models/company_profile.dart` passou a expor:
  - provider configurado
  - `connection_id` da conta ligada
- `lib/services/company_service.dart` passou a:
  - tolerar schemas antigos sem as colunas novas
  - remover colunas nao suportadas antes do `upsert`
- `lib/company_settings_page.dart` passou a:
  - permitir escolher `manual`, `google` ou `microsoft`
  - listar contas ligadas disponiveis por fornecedor
  - mostrar estado, ultima sincronizacao e ultimo erro da conta ligada
  - manter o remetente visivel e assinatura global
- `lib/calendar_page.dart` passou a:
  - usar o perfil da empresa em vez de ler `company_profile` de forma ad-hoc
  - mostrar fornecedor, conta ligada e nota de readiness nos rascunhos de email
- Foi criado `EMAIL_PROVIDER_OAUTH_SETUP.md` com o proximo passo tecnico para:
  - Google OAuth + Gmail API
  - Microsoft OAuth + Graph `sendMail`
  - funcoes backend/Edge Functions recomendadas
- Validacao conseguida neste ambiente:
  - `dart.exe format` executado com sucesso nos ficheiros alterados
- Validacao bloqueada neste ambiente:
  - `dart analyze` continuou a falhar com `CreateFile failed 5 (Acesso negado)` ao arrancar o analysis server

## Sessao 2026-03-28 OAuth Backend para Contas de Email
- Foi adicionada a base backend para ligar contas `Google / Gmail` e `Microsoft / Hotmail / Outlook`
- Novo script `SUPABASE_EMAIL_PROVIDER_BACKEND.sql`:
  - cria `company_email_connection_credentials`
  - guarda refresh/access tokens fora da leitura normal da app
  - ativa RLS sem policies para bloquear acesso autenticado comum
- Nova infraestrutura de Edge Functions em `supabase/functions`:
  - `_shared/email_provider_oauth.ts`
  - `email-provider-start/index.ts`
  - `email-provider-callback/index.ts`
  - `README.md` com env vars e deploy
- Correcao importante:
  - o callback documentado para os providers deve usar o formato Supabase atual
    `https://<project-ref>.supabase.co/functions/v1/email-provider-callback`
  - o URL de consentimento Google passou a enviar `prompt=consent` para facilitar a obtencao de `refresh_token`
- `lib/services/email_provider_auth_service.dart` foi criado para:
  - invocar `email-provider-start`
  - abrir o browser para consentimento OAuth
- `lib/company_settings_page.dart` foi atualizado com:
  - botao para ligar Google/Microsoft
  - refresh manual da lista de contas ligadas
  - mensagens de orientacao apos regressar do browser
- Documentacao adicional afinada em `EMAIL_PROVIDER_OAUTH_SETUP.md`
- Validacao conseguida neste ambiente:
  - `dart.exe format` executado com sucesso
- Validacao bloqueada neste ambiente:
  - `dart analyze` continuou a falhar com `CreateFile failed 5 (Acesso negado)`
  - `deno` nao esta instalado neste ambiente, por isso nao houve `deno check` local das Edge Functions

## Sessao 2026-03-28 Deploy das Edge Functions de OAuth
- O deploy real das functions `email-provider-start` e `email-provider-callback` foi executado com sucesso no projeto `uaupakkizxmwgcfrtnnz`
- Foi corrigido um erro de sintaxe TypeScript em `supabase/functions/_shared/email_provider_oauth.ts`:
  - acesso opcional a `existingCredentials?.["refresh_token"]`
- Resultado pratico:
  - o backend OAuth ficou ativo no Supabase para teste real com `Google / Gmail`
  - a parte `Microsoft` continua preparada no codigo, mas ainda depende de criar e configurar a app correspondente no Microsoft Entra

## Sessao 2026-03-28 Ativacao Google OAuth e ponto de retoma
- O utilizador colocou a app Google OAuth em `In production`
- O `redirect URI` configurado para Google ficou:
  - `https://uaupakkizxmwgcfrtnnz.supabase.co/functions/v1/email-provider-callback`
- Secrets configurados no Supabase para o fluxo Google:
  - `EMAIL_PROVIDER_STATE_SECRET`
  - `GOOGLE_OAUTH_CLIENT_ID`
  - `GOOGLE_OAUTH_CLIENT_SECRET`
  - `EMAIL_PROVIDER_CALLBACK_URL`
- Scripts SQL ja aplicados no Supabase sem erros:
  - `SUPABASE_EMAIL_PROVIDER_FOUNDATION.sql`
  - `SUPABASE_EMAIL_PROVIDER_BACKEND.sql`
- O CLI local do Supabase foi executado via `npx.cmd` por bloqueio do `PowerShell` a `npx.ps1`
- Ponto em que a sessao ficou:
  - o utilizador ainda nao estava a ver a opcao `Google / Gmail` na app Android
  - a causa mais provavel e estar a correr uma build antiga
  - proximo passo: arrancar a app novamente a partir do projeto atual com `flutter run` e validar no ecra `Configuracao da empresa` > `Email de autorizacoes`

## Sessao 2026-03-29 Registo Self-Service com Empresa Nova
- O ecrã de autenticacao passou a permitir `Criar conta` diretamente na app, com:
  - nome completo
  - nome da empresa
  - email
  - palavra-passe + confirmacao
- As novas contas deixam de cair num estado invalido sem empresa:
  - `main.dart` ganhou um gate autenticado
  - quando a conta ainda nao tem `company_id`, a app mostra `AccountSetupPage`
  - o utilizador termina o onboarding antes de entrar no `HomePage`
- Foi criado `lib/services/account_setup_service.dart` para:
  - detetar se a conta atual ainda precisa de empresa
  - invocar o bootstrap backend
- Foi criada a Edge Function `supabase/functions/account-bootstrap/index.ts`:
  - valida o utilizador autenticado
  - cria uma nova `company`
  - promove o perfil atual a `admin`
  - associa `company_id` ao perfil
  - cria/atualiza `company_profile`
  - atualiza os metadados do utilizador
- `supabase/functions/README.md` foi atualizado com a nova function
- O deploy real da function `account-bootstrap` foi executado com sucesso no projeto `uaupakkizxmwgcfrtnnz`
- A versao web publica tambem foi atualizada na Netlify:
  - `https://cmmscompinta.netlify.app`
- Validacao conseguida neste ambiente:
  - `dart.exe format` executado com sucesso nos ficheiros Dart alterados
  - `flutter build apk --debug` executado com sucesso
  - a APK debug atualizada ficou em `build/app/outputs/flutter-apk/app-debug.apk`
  - `flutter build web` executado com sucesso
  - deploy de producao Netlify concluido com sucesso
- Validacao ainda por fazer fora deste ambiente:
  - smoke test completo com uma conta nova real a passar por `Criar conta` + `Criar empresa e continuar`

## Sessao 2026-03-29 Automacao do Build Number Android
- O fluxo `Firebase App Distribution` passou a gerar automaticamente um
  `build number` Android novo em cada build, sem obrigar a editar o
  `pubspec.yaml`
- `scripts/deploy_android_firebase.ps1` passou a:
  - ler o `build name` do `pubspec.yaml`
  - calcular um `build number` monotono com base no tempo UTC
  - guardar o ultimo numero localmente em `.firebase/android-build-number-<tipo>.txt`
  - passar `--build-name` e `--build-number` ao `flutter build apk`
- `FIREBASE_APP_DISTRIBUTION_SETUP.md` e `README.md` foram atualizados para
  refletir este comportamento
- Objetivo:
  - evitar esquecimentos manuais antes de cada distribuicao
  - garantir que o Android aceita sempre a nova build como atualizacao da app
- Validacao:
  - `scripts/deploy_android_firebase.ps1 -SkipDistribute` executado com sucesso
  - build `release` validada automaticamente com versao `1.0.0 (260881926)`

## Sessao 2026-03-29 Firebase Release Publicada e Testers Atualizados
- Foi publicada uma nova release Android no Firebase App Distribution com:
  - versao `1.0.0 (260881930)`
  - nota: `Registo self-service, criacao de empresa nova e melhorias no onboarding`
- A distribuicao dessa release ficou concluida com sucesso para:
  - `micaelpcunha@gmail.com`
- A configuracao local de testers foi atualizada em
  `scripts/firebase_app_distribution.local.ps1`
  para incluir tambem:
  - `pintadooceano@gmail.com`
- Efeito pratico:
  - as proximas releases publicadas pelo script vao automaticamente para os dois testers
  - se for preciso que `pintadooceano@gmail.com` receba tambem a release `260881930`,
    convem redistribuir essa release ou publicar a proxima build

## Sessao 2026-04-01 Dispositivos dentro dos Ativos com QR e Documentacao
- Foi adicionada a base funcional para gerir dispositivos dentro de cada ativo,
  com foco em equipamentos/sub-elementos como portas de emergencia, quadros
  eletricos ou maquinas de ar condicionado
- Foi criada a migration
  `supabase/migrations/20260401073400_asset_devices.sql`
  para suportar aplicacao da mesma alteracao via `supabase db push`
- Novo script canónico `SUPABASE_ASSET_DEVICES.sql`:
  - cria `asset_devices` como tabela filha de `assets`
  - guarda `name`, `description`, `manufacturer_reference`,
    `internal_reference`, `qr_code` e `documentation`
  - adiciona `can_edit_asset_devices` a `profiles` e `technicians`
  - alinha `company_id`, triggers de `updated_at` e policies RLS
  - deixa os tecnicos com `can_edit_assets = true` mapeados por defeito para
    `can_edit_asset_devices = true` para nao perderem capacidade no arranque
- A app Flutter passou a:
  - mostrar uma area de `Dispositivos` dentro do detalhe do ativo
  - abrir um ecrã dedicado para listar, criar, editar e eliminar dispositivos
  - permitir associar ou gerar QR proprio por dispositivo
  - permitir anexar documentacao em fotografias e PDF por dispositivo
  - reutilizar o bucket privado `company-media` para guardar essa documentacao
- A gestao de tecnicos passou a expor uma permissao propria:
  - `Pode criar e editar dispositivos`
  - esta permissao fica separada de `Pode editar ativos`
- Outros ajustes de suporte:
  - `HomePage`, `LocationsPage`, `AssetsPage`, `UserProfile`,
    `Technician` e `ProfileService` foram alinhados com a nova permissao
  - `SUPABASE_PRODUCT_FOUNDATION.sql`,
    `SUPABASE_MULTITENANT_RLS.sql`,
    `SUPABASE_SECURITY_HARDENING.sql` e
    `SUPABASE_MULTITENANT_VALIDATION.sql`
    foram atualizados para refletir o novo modelo
- Validacao conseguida neste ambiente:
  - `C:\Users\pinta\develop\flutter\bin\cache\dart-sdk\bin\dart.exe format`
    executado com sucesso nos ficheiros Dart alterados
- Validacao bloqueada neste ambiente:
  - `dart analyze` continuou a falhar com
    `CreateFile failed 5 (Acesso negado)`
  - `flutter test test/widget_test.dart` nao concluiu dentro do timeout do
    ambiente
- A migration foi aplicada com sucesso ao projeto Supabase
  `uaupakkizxmwgcfrtnnz` via `supabase link` + `supabase db push`

## Sessao 2026-04-01 Deploy Web e Android dos Dispositivos
- Foi publicado o frontend web em producao na Netlify com a funcionalidade de
  dispositivos dentro dos ativos, incluindo QR, documentacao e permissao
  propria para tecnicos
- URL de producao web confirmada:
  `https://cmmscompinta.netlify.app`
- Foi gerada e distribuida uma nova build Android release pelo Firebase App
  Distribution:
  - versao `1.0.0`
  - build `260910707`
  - notas de release: `Dispositivos nos ativos com QR, documentacao e nova permissao de tecnicos`
- A distribuicao Android ficou enviada para os testers configurados no projeto
- Nao havia nenhum dispositivo ligado por `adb`, por isso nao foi feita
  instalacao local nem validacao direta em equipamento Android nesta sessao

## Sessao 2026-04-01 Modo Offline para Tecnicos nas Ordens
- Foi adicionada uma base offline para tecnicos nas ordens de trabalho:
  - cache local persistente das ordens visiveis
  - fila local de alteracoes pendentes por sincronizar
  - sincronizacao automatica em segundo plano e no regresso da app ao primeiro plano
- O arranque autenticado passou a tolerar falta de rede quando ja existe estado
  local valido:
  - `AccountSetupService` guarda e reutiliza o ultimo estado conhecido
  - `ProfileService` guarda e reutiliza o ultimo perfil conhecido
  - isto permite ao tecnico entrar na app offline depois de ja ter iniciado
    sessao com internet pelo menos uma vez
- O ecrã `Minhas ordens` passou a:
  - usar a nova camada `WorkOrderOfflineService`
  - mostrar banner de `Modo offline`
  - indicar quantas alteracoes estao por sincronizar
  - mostrar a ultima sincronizacao conhecida
- O detalhe da ordem passou a permitir ao tecnico, mesmo sem rede:
  - alterar estado
  - atualizar observacoes
  - atualizar medicao
  - atualizar checklist do procedimento
  - guardar localmente essas alteracoes para envio automatico quando houver ligacao
- As fotografias continuam dependentes de upload remoto para o storage, por isso
  nao ficaram incluidas neste primeiro passo do modo offline
- Ficheiros principais desta entrega:
  - `lib/services/local_cache_service.dart`
  - `lib/services/work_order_offline_service.dart`
  - `lib/services/account_setup_service.dart`
  - `lib/services/profile_service.dart`
  - `lib/home_page.dart`
  - `lib/work_orders/work_orders_page.dart`
  - `lib/work_orders/task_detail_page.dart`
  - `pubspec.yaml`
- Validacao conseguida neste ambiente:
  - `dart format` executado com sucesso nos ficheiros alterados
  - `flutter pub get` executado com sucesso
  - `flutter analyze` executado com sucesso sem erros de compilacao nas pecas
    alteradas; ficaram apenas `info` de estilo/deprecacoes ja presentes no projeto
- Validacao bloqueada neste ambiente:
  - `flutter test --no-pub test/widget_test.dart` nao concluiu dentro do timeout
    do ambiente
  - nao havia nenhum dispositivo Android ligado por `adb`, por isso nao houve
    instalacao local nem validacao em equipamento real desta funcionalidade offline

## Sessao 2026-04-01 Preparacao de Arranque iOS no Mac
- Foi retomada a integracao iOS agora com foco em primeiro arranque real no Mac
- Confirmado no repositorio:
  - `Bundle ID` iOS continua em `com.micaelcunha.mantra`
  - target minimo iOS continua em `13.0`
  - permissao de camara para QR e permissao de fotografias ja estavam no `Info.plist`
- O script `scripts/prepare_ios_on_mac.sh` foi melhorado para:
  - validar que esta a correr num Mac
  - confirmar a presenca de `flutter`, `xcodebuild` e `pod`
  - orientar o proximo passo no Xcode antes de pensar em archive/TestFlight
- Foi criado o script `scripts/run_ios_debug_on_mac.sh` para facilitar:
  - `flutter pub get`
  - `pod install`
  - listar dispositivos
  - correr `flutter run` no Mac
- O guia `IOS_TESTFLIGHT_SETUP.md` foi atualizado para incluir:
  - o novo script de debug
  - uma validacao local em iPhone antes do primeiro archive
- Validacao conseguida neste ambiente Windows:
  - leitura e confirmacao dos ficheiros iOS do projeto
  - sem validacao real de build iOS, porque continua dependente de Xcode no Mac

## Sessao 2026-04-01 Nota Audio nas Ordens de Trabalho
- Foi preparada a `V1` de nota audio nas ordens para a vista de tecnico:
  - botao de `premir e manter` para gravar
  - ao largar, a gravacao para e o audio fica associado a ordem
  - reproducao simples do audio gravado dentro do detalhe da ordem
- A implementacao foi mantida deliberadamente simples:
  - sem transcricao
  - sem suporte offline especifico
  - sem nova tabela dedicada; nesta primeira versao fica um unico `audio_note_url`
    diretamente em `work_orders`
- Foi reutilizado o bucket privado `work-order-attachments` para guardar as
  notas audio, evitando criar mais buckets/politicas nesta fase
- Ficheiros principais desta entrega:
  - `lib/work_orders/task_detail_page.dart`
  - `lib/services/storage_service.dart`
  - `lib/work_orders/work_order_helpers.dart`
  - `pubspec.yaml`
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner/Info.plist`
  - `SUPABASE_WORK_ORDER_AUDIO_NOTES.sql`
  - `supabase/migrations/20260401162500_work_order_audio_notes.sql`
- Dependencias novas:
  - `record`
  - `audioplayers`
  - `cross_file` como dependencia direta
- Validacao conseguida neste ambiente:
  - `flutter pub get` executado com sucesso
  - `dart format` executado com sucesso nos ficheiros Dart alterados
  - `flutter analyze` executado com sucesso sem issues nos ficheiros alterados
- Pendente operacional:
  - a coluna `audio_note_url` ficou preparada em SQL, mas a migration ainda nao
    foi aplicada ao Supabase nesta sessao
  - nao houve validacao em Android/iOS real nesta sessao
- Ponto de retoma recomendado:
  - aplicar `SUPABASE_WORK_ORDER_AUDIO_NOTES.sql` no projeto Supabase
  - publicar web e Android com esta funcionalidade
  - validar em equipamento real a gravacao, o upload e a reproducao da nota audio

## Sessao 2026-04-01 Registo Canonico do Catch-Up de RLS
- Foi registada no repositorio a correcao de seguranca feita no Supabase para
  duas tabelas publicas legacy que estavam fora das migrations:
  - `memberships`
  - `work_order_qr_validations`
- Nova migration criada:
  - `supabase/migrations/20260401184500_enable_rls_for_memberships_and_work_order_qr_validations.sql`
- O `SUPABASE_SECURITY_CHECKLIST.md` passou a incluir estas tabelas, juntamente
  com as restantes tabelas publicas atuais, na verificacao base de `RLS` e de
  policies
- Motivo:
  - evitar que a correcao fique apenas live no projeto Supabase
  - reduzir drift entre a base de dados real e o SQL versionado
- Validacao:
  - confirmada via SQL no Supabase a transicao para `rowsecurity = true` em
    `memberships` e `work_order_qr_validations`
  - confirmada contagem `0` em ambas as tabelas no momento da correcao

## Sessao 2026-04-01 Ativacao Live da Nota Audio e Nova Build Android
- Foi confirmada a causa pela qual o botao de gravacao audio ainda nao aparecia
  na app:
  - a coluna `public.work_orders.audio_note_url` ainda nao existia no Supabase
    remoto
- Foram aplicadas ao projeto Supabase `uaupakkizxmwgcfrtnnz` as migrations
  pendentes via `npx supabase db push`:
  - `20260401162500_work_order_audio_notes.sql`
  - `20260401184500_enable_rls_for_memberships_and_work_order_qr_validations.sql`
- Depois da aplicacao, a verificacao remota por REST deixou de falhar com
  `column work_orders.audio_note_url does not exist` e passou a aceitar
  `select=id,audio_note_url` com `HTTP 200`
- Foi gerada e distribuida uma nova build Android release pelo Firebase App
  Distribution para validacao desta funcionalidade:
  - versao `1.0.0`
  - build `260911903`
  - notas de release:
    `Validacao da nota audio apos ativacao de audio_note_url no Supabase`
- A distribuicao ficou enviada para os testers configurados:
  - `micaelpcunha@gmail.com`
  - `pintadooceano@gmail.com`
- Validacao:
  - `build/app/outputs/flutter-apk/app-release.apk` gerada com sucesso
  - release criada com sucesso no Firebase App Distribution
  - nao havia nenhum dispositivo ligado por `adb`, por isso nao houve
    instalacao local nem validacao direta em equipamento Android nesta sessao

## Sessao 2026-04-01 Reordenacao da Nota Audio na Vista de Tecnico
- O detalhe da ordem de trabalho foi ajustado para mostrar o cartao `Nota audio`
  mais abaixo na vista de tecnico:
  - depois de `Observacoes`
  - antes de `Anexo`
- Ficheiro alterado:
  - `lib/work_orders/task_detail_page.dart`
- Foi gerada e distribuida nova build Android release para validar este ajuste:
  - versao `1.0.0`
  - build `260911925`
  - notas de release:
    `Mover nota audio para depois das observacoes na vista de tecnico`
- Validacao:
  - `build/app/outputs/flutter-apk/app-release.apk` gerada com sucesso
  - release criada e distribuida com sucesso no Firebase App Distribution
  - `flutter analyze` local ao ficheiro nao concluiu neste ambiente e
    `dart analyze` continuou a falhar com `CreateFile failed 5 (Acesso negado)`

## Sessao 2026-04-01 Limpeza de Analyze e Validacao Base
- Foi feita uma passagem de qualidade ao projeto com foco em avisos do
  analisador com maior impacto pratico
- Ajustes aplicados:
  - `lib/calendar_page.dart` limpo de `unnecessary_cast` e de um `if` sem
    chavetas
  - `lib/alerts_page.dart`, `lib/locations_page.dart` e `lib/users_page.dart`
    ficaram mais seguros em navegacao/feedback apos `await`, reduzindo risco de
    uso de `context` fora de tempo
  - `lib/main.dart` deixou de expor um tipo privado na API publica de `MyApp`
  - `lib/technicians_page.dart` e `lib/users_page.dart` deixaram de depender de
    non-null assertions desnecessarias em fluxos de criacao de contas
- Resultado da limpeza:
  - os `warnings` reais do `flutter analyze` ficaram eliminados nesta passagem
  - o projeto continua com varios `info` de modernizacao/estilo
    (`withOpacity`, `value` deprecated, `return` em `finally`, etc.) que podem
    ser tratados numa ronda dedicada sem impacto funcional
- Validacao:
  - `flutter analyze` executado com sucesso fora da sandbox, sem warnings
    restantes
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso:
    `All tests passed!`

## Sessao 2026-04-01 Calendario com Edicao do Dia e Ativos sem Ordem
- O planeamento do calendario deixou de depender apenas de ordens de trabalho:
  - o administrador pode agora incluir um ativo no dia mesmo sem existir
    qualquer ordem em aberto associada
  - o fluxo de `Planear dia` passou a funcionar tambem como `Editar dia`,
    abrindo com o estado ja carregado por tecnico e permitindo acrescentar ou
    retirar ordens do plano
- Foi adicionada persistencia backend para estes ativos planeados sem ordem:
  - SQL canonico em `SUPABASE_CALENDAR_PLANNED_DAY_ASSETS.sql`
  - migration versionada
    `supabase/migrations/20260401224500_calendar_planned_day_assets.sql`
  - nova tabela `public.planned_day_assets` com `RLS`, indices e validacao de
    empresa via `asset_id` + `technician_id`
- No frontend do calendario:
  - a pagina de planeamento mostra todos os ativos, mesmo os que nao tenham
    ordens em aberto
  - cada ativo pode ficar marcado no dia sem ordem associada
  - ao reabrir um dia ja planeado, as ordens desse tecnico aparecem
    pre-selecionadas e as ordens retiradas do plano ficam novamente sem data
    planeada
  - a agenda do dia e a contagem do calendario passaram a refletir tambem os
    ativos planeados sem ordem
  - os rascunhos de email de autorizacao passaram a suportar ativos sem ordens,
    usando a mensagem `Visita planeada sem ordem associada`
- Validacao:
  - `flutter analyze` voltou a passar sem erros nem warnings novos; ficaram
    apenas os `info` historicos do projeto
  - `flutter test --no-pub test/widget_test.dart` passou com `All tests passed!`
  - `npx supabase db push` aplicou com sucesso a migration
    `20260401224500_calendar_planned_day_assets.sql` no projeto remoto
  - nova build Android release gerada e distribuida via Firebase App
    Distribution:
    - versao `1.0.0`
    - build `260912024`
  - notas de release:
      `Calendario: editar dia planeado e planear ativos sem ordem`
  - a distribuicao ficou disponivel em:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/1cj1kjnvvjmd0?utm_source=firebase-tools`

## Sessao 2026-04-01 Envio Real de Emails de Autorizacao
- O fluxo de autorizacoes por email deixou de ficar apenas em preview:
  - o planeamento do calendario tenta agora enviar os emails reais quando a
    empresa estiver configurada com `Automatico apos planear` e uma conta
    Google/Microsoft ligada e pronta
  - quando o envio automatico nao esta disponivel, a app explica por que razao
    ficou em modo de revisao manual em vez de fingir que enviou
- Backend adicionado para o envio real:
  - nova Edge Function
    `supabase/functions/authorization-email-send/index.ts`
  - helper partilhado para refresh de tokens e envio via Gmail API / Microsoft
    Graph em `supabase/functions/_shared/email_provider_delivery.ts`
  - README das functions atualizado para incluir o novo deploy
- Suporte canonico de base de dados registado no repositorio:
  - `SUPABASE_EMAIL_PROVIDER_FOUNDATION.sql` passou a incluir
    `authorization_email_send_mode`, `authorization_email_signature`,
    `authorization_sender_email` e a tabela
    `authorization_email_delivery_logs`
  - migration versionada
    `supabase/migrations/20260401233500_authorization_email_delivery_support.sql`
    aplicada com sucesso no projeto remoto
- Ajustes no frontend:
  - `lib/services/authorization_email_delivery_service.dart` faz a chamada da
    Edge Function e normaliza resultados/erros
  - `lib/calendar_page.dart` passou a:
    - enviar automaticamente os drafts confirmados quando a conta estiver pronta
    - mostrar resumo do envio e estado por ativo (enviado/erro) na preview
    - manter fallback claro para revisao manual quando a conta nao existe, nao
      esta ligada ou precisa de reautenticacao
  - `lib/company_settings_page.dart` passou a refletir que o backend de envio
    ja esta ativo e clarifica o campo de email como `Reply-To` / resposta
  - `lib/services/company_service.dart` ficou compativel com estas novas colunas
    mesmo em ambientes ainda sem migration aplicada
- Validacao:
  - `flutter analyze` aos ficheiros alterados executado com sucesso fora da
    sandbox; nao apareceram erros nem warnings novos, apenas `info` historicos
    do projeto
  - `flutter test --no-pub test/widget_test.dart` passou com `All tests passed!`
  - `npx supabase migration list` confirmou `Local = Remote` ate
    `20260401233500`
  - `npx supabase functions deploy authorization-email-send --project-ref uaupakkizxmwgcfrtnnz`
    publicou a function com sucesso
  - nova build Android release gerada e distribuida via Firebase App
    Distribution:
    - versao `1.0.0`
    - build `260912051`
    - notas de release:
      `Autorizacoes por email: envio automatico real no planeamento e feedback de entrega`
  - a distribuicao ficou disponivel em:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/0sss5r12i21bo?utm_source=firebase-tools`
  - nao havia nenhum dispositivo ligado por `adb`, por isso nao foi possivel
    instalar a build diretamente no Android nesta sessao

## Sessao 2026-04-03 Correcao do Callback Google OAuth para Perfil da Empresa
- Foi corrigido o backend OAuth para os casos em que a ligacao Google chegava a
  guardar a conta em `company_email_connections`, mas falhava ao fixar essa
  conta no `company_profile`
- Ajuste aplicado em:
  - `supabase/functions/_shared/email_provider_oauth.ts`
- Comportamento novo:
  - o callback passa a procurar primeiro um `company_profile` existente por
    `company_id`
  - se o perfil existir, atualiza apenas
    `authorization_email_provider` e `authorization_email_connection_id`
  - se o perfil ainda nao existir, cria-o com fallback seguro a partir da
    tabela `companies` antes de guardar a associacao OAuth
- Motivo:
  - evitar falhas como `A conta foi ligada, mas nao foi possivel atualizar o
    perfil da empresa` durante a ligacao do remetente Google
  - tornar o fluxo mais robusto para empresas legacy ou com perfil incompleto
- Validacao:
  - `npx.cmd supabase functions deploy email-provider-callback --project-ref uaupakkizxmwgcfrtnnz`
    executado com sucesso
  - asset partilhado `_shared/email_provider_oauth.ts` foi incluido no deploy
  - nao houve repeticao do fluxo OAuth completo neste ambiente apos o deploy;
    a validacao final depende de repetir a ligacao na app

## Sessao 2026-04-03 Correcao do Verify JWT no Envio Automatico de Emails
- Foi corrigida a configuracao de deploy da Edge Function
  `authorization-email-send` para evitar o erro:
  - `A function de envio nao aceitou a sessao autenticada`
- Ajustes aplicados:
  - `supabase/config.toml`
  - `supabase/functions/README.md`
- Comportamento novo:
  - `authorization-email-send` fica agora explicitamente publicada com
    `verify_jwt = false`
  - a validacao do admin continua a ser feita dentro do proprio codigo com
    `requireAdminContext`, tal como nas functions OAuth relacionadas
- Motivo:
  - alinhar esta function com o padrao backend ja usado em
    `email-provider-start` e `email-provider-callback`
  - evitar falhas do gateway Supabase com `Invalid JWT` no arranque do envio
    automatico a partir da app
- Validacao:
  - `npx.cmd supabase functions deploy authorization-email-send --project-ref uaupakkizxmwgcfrtnnz`
    executado com sucesso
  - os assets `_shared/email_provider_delivery.ts` e
    `_shared/email_provider_oauth.ts` seguiram no deploy
  - nao houve envio real repetido neste ambiente apos o deploy; a validacao
    final depende de novo teste na app e, se necessario, de voltar a entrar na
    conta para renovar a sessao local

## Sessao 2026-04-03 Remocao de Imagens na Empresa, Ativos e Localizacoes
- Os formularios passaram a permitir remover imagens ja carregadas sem ficar
  presos apenas a substituir ficheiros
- Ajustes na empresa:
  - `lib/company_settings_page.dart` passou a mostrar `Remover capa` e
    `Remover logotipo`
  - a remocao fica refletida no rascunho local e e confirmada ao guardar os
    dados da empresa
  - os ficheiros antigos ficam marcados para limpeza no bucket `company-media`
    depois de um `save` bem-sucedido
- Ajustes nos ativos:
  - `lib/assets_pages.dart` passou a permitir remover a foto no formulario de
    criacao/edicao
  - a vista de detalhe do ativo passou a permitir remover a fotografia de forma
    imediata
  - substituicoes e remocoes limpam ficheiros antigos do bucket
    `asset-profile-photos` apos a persistencia
- Ajustes nas localizacoes:
  - `lib/locations_page.dart` passou a permitir remover a fotografia no
    formulario
  - substituicoes e remocoes limpam ficheiros antigos do bucket
    `location-photos` apos guardar
- Motivo:
  - desbloquear a gestao de identidade visual e de fotografias sem obrigar a
    manter imagens erradas ou desatualizadas
  - reduzir lixo de storage quando uma imagem e substituida ou anulada
- Validacao:
  - `dart format` executado com sucesso em
    `lib/company_settings_page.dart`, `lib/assets_pages.dart` e
    `lib/locations_page.dart`
  - `dart analyze` aos tres ficheiros executado com sucesso fora da sandbox,
    sem erros novos; ficaram apenas `info` historicos do projeto

## Sessao 2026-04-03 Remocao e Limpeza de Contas Ligadas de Remetente
- A configuracao de email da empresa passou a permitir limpar ou eliminar
  contas ligadas que tinham ficado presas como remetente
- Ajustes aplicados:
  - `lib/company_settings_page.dart`
  - `lib/services/company_email_connection_service.dart`
- Comportamento novo:
  - o dropdown `Conta ligada para envio` passou a incluir a opcao
    `Sem conta ligada ativa`
  - cada cartao de conta ligada passou a permitir:
    - `Deixar de usar` no rascunho atual
    - `Eliminar conta ligada` com confirmacao
  - quando a conta eliminada era a conta ativa da empresa:
    - a associacao ao perfil e atualizada automaticamente
    - se nao existir alternativa ligada, o envio volta a `manual`
- Motivo:
  - evitar ficar preso a uma conta Google/Microsoft previamente associada como
    remetente
  - permitir limpar a configuracao sem ter de manter contas ligadas obsoletas
- Validacao:
  - `dart format` executado com sucesso em
    `lib/company_settings_page.dart` e
    `lib/services/company_email_connection_service.dart`
  - `dart analyze` aos dois ficheiros executado com sucesso fora da sandbox,
    sem erros novos; ficaram apenas `info` historicos do projeto

## Sessao 2026-04-03 Deploy Web Netlify com Estado Atual
- Foi publicada uma nova versao web de producao com o estado atual do projeto,
  incluindo as correcoes recentes na configuracao da empresa, imagens e contas
  ligadas de remetente
- Deploy executado por:
  - `scripts/deploy_web_netlify.ps1`
- Validacao:
  - `flutter build web` executado com sucesso
  - deploy de producao Netlify concluido com sucesso
  - URL de producao:
    `https://cmmscompinta.netlify.app`
  - URL unica do deploy:
    `https://69cfd2905db9bb5002f6f07e--cmmscompinta.netlify.app`

## Sessao 2026-04-03 Retoma pelo PROJECT_NOTES
- Foi retomado o contexto do projeto a partir do historico registado em
  `PROJECT_NOTES.md`, para continuar o trabalho sem depender da conversa
  anterior
- Estado funcional mais recente confirmado:
  - as correcoes ao callback Google OAuth e ao `verify_jwt` do envio
    automatico ja ficaram publicadas no Supabase
  - a versao web de producao ja foi atualizada na Netlify com esse estado
  - ainda nao ficou registada uma nova build Android release depois destas
    correcoes
- Proximo passo recomendado ao retomar:
  - gerar uma nova build Android release com
    `scripts/deploy_android_firebase.ps1`
  - distribuir essa build no Firebase App Distribution
  - validar na app Android:
    - a ligacao Google / Gmail
    - o envio automatico real de emails de autorizacao
    - a limpeza de imagens e de contas ligadas de remetente
- Validacao:
  - contexto recente revisto diretamente nas ultimas sessoes do
    `PROJECT_NOTES.md`
  - `scripts/deploy_android_firebase.ps1` revisto como fluxo atual para a
    proxima release Android

## Sessao 2026-04-03 Atualizacao dos Icones da App
- Os icones da aplicacao foram regenerados a partir da imagem fornecida:
  - `C:\Users\pinta\OneDrive\mantra\AppIcons (1)\appstore.png`
- Foi criado um fluxo reproduzivel para futuras trocas de icones:
  - `scripts/update_app_icons.ps1`
- O script passou a atualizar automaticamente:
  - icones Android `mipmap-*`
  - foreground do launcher adaptativo Android
  - `AppIcon` de iOS
  - `AppIcon` de macOS
  - `favicon` e icons web
  - `app_icon.ico` de Windows
- Foram guardados no repositorio dois assets de apoio:
  - `assets/branding/mantra_app_icon_source.png`
  - `assets/branding/mantra_app_icon_foreground.png`
- Ajuste Android adicional:
  - `android/app/src/main/res/values/colors.xml`
  - `android/app/src/main/res/values-night/colors.xml`
  - o `mantra_launcher_background` passou para branco, para o icone
    adaptativo ficar alinhado com a imagem base em vez de manter o fundo azul
    escuro anterior
- Documentacao atualizada:
  - `README.md` passou a explicar como regenerar os icones a partir de uma
    imagem base
- Validacao:
  - `scripts/update_app_icons.ps1` executado com sucesso com a imagem fornecida
  - pre-visualizacao manual confirmada para:
    - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
    - `android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png`
    - `web/favicon.png`
  - tamanhos finais confirmados para Android, Web, iOS, macOS e Windows
  - nao foi executada build completa da app nesta sessao

## Sessao 2026-04-03 Logo Original no Login e Cabecalho
- O login e o cabecalho principal passaram a usar a imagem original indicada
  pelo utilizador, sem trocar para uma versao limpa da marca:
  - `C:\Users\pinta\OneDrive\mantra\Mantra logo.png`
- Foi confirmado que o ficheiro versionado
  `assets/branding/mantra_logo.png` corresponde ao mesmo conteudo da origem
  original
- Ajustes aplicados:
  - `lib/config/branding.dart` passou a apontar `productLogoAsset` para
    `assets/branding/mantra_logo.png`
  - `pubspec.yaml` passou a expor toda a pasta `assets/branding/`
  - `lib/login_page.dart` passou a mostrar o logo original com enquadramento
    proprio e sem repetir o nome `MANTRA` em texto por baixo
  - `lib/home_page.dart` passou a mostrar o logo original no cabecalho sem
    repetir o nome da app em texto ao lado
  - `lib/account_setup_page.dart` ficou alinhada com o mesmo asset de branding
    no fluxo de onboarding
- Motivo:
  - respeitar o pedido de usar exatamente a imagem original no branding visivel
    da app
  - evitar duplicacao visual do nome da app quando o proprio ficheiro ja inclui
    a palavra `MANTRA`
- Validacao:
  - `dart format` executado com sucesso em `branding.dart`, `login_page.dart`,
    `home_page.dart` e `account_setup_page.dart`
  - hash SHA-256 confirmado igual entre a origem no OneDrive e
    `assets/branding/mantra_logo.png`
  - nao foi executada build completa da app nesta sessao

## Sessao 2026-04-03 Limpeza Segura da Conta Ligada Ativa de Remetente
- A eliminacao de uma conta ligada usada como remetente ativo deixou de poder
  reencaminhar silenciosamente o perfil para outra conta do mesmo fornecedor
- Ajustes na app:
  - `lib/services/company_email_connection_service.dart` passou a preferir um
    RPC backend `delete_company_email_connection`
  - quando esse RPC ainda nao existe, o cliente faz fallback seguro:
    - limpa o perfil da empresa para `manual`
    - remove a `authorization_email_connection_id`
    - limpa tambem o `authorization_sender_email` quando ele coincide com a
      conta eliminada
  - `lib/company_settings_page.dart` deixou de escolher automaticamente outra
    conta no refresh e passou a recarregar o estado real do perfil depois da
    eliminacao
  - a mensagem de feedback passou a indicar quando a limpeza backend de
    credenciais OAuth foi concluida
- Ajustes canonicos de base de dados:
  - `SUPABASE_EMAIL_PROVIDER_FOUNDATION.sql` passou a incluir a function
    `public.delete_company_email_connection(uuid)`
  - nova migration versionada:
    `supabase/migrations/20260403173000_delete_company_email_connection_cleanup.sql`
- Comportamento novo no Supabase:
  - se a conta eliminada era a conta ativa da empresa, o perfil volta para:
    - `authorization_email_provider = manual`
    - `authorization_email_send_mode = manual`
    - `authorization_email_connection_id = null`
  - se o `authorization_sender_email` coincidir com o email da conta apagada,
    esse campo tambem e limpo
  - o delete da ligacao continua a apagar as credenciais em
    `company_email_connection_credentials` por `on delete cascade`
  - os logs de entrega mantem historico mas ficam desacoplados da ligacao por
    `on delete set null`
- Motivo:
  - evitar que apagar a conta ativa acabe por deixar outra conta ativa sem
    decisao explicita do admin
  - reduzir risco de credenciais ou associacoes stale no backend
- Validacao:
  - `dart format` executado com sucesso em
    `lib/services/company_email_connection_service.dart` e
    `lib/company_settings_page.dart`
  - `npx.cmd supabase db push` aplicou com sucesso a migration
    `20260403173000_delete_company_email_connection_cleanup.sql`
  - `npx.cmd supabase migration list` confirmou `Local = Remote`
  - `dart analyze` nao foi concluido neste ambiente por continuar a falhar com
    `CreateFile failed 5 (Acesso negado)`

## Sessao 2026-04-03 Backup e Preview do Import Infraspeak
- Foi preparado um fluxo local para testar a importacao do Excel exportado do
  Infraspeak sem perder a possibilidade de reverter o estado atual
- Novos scripts:
  - `scripts/backup_supabase_public.ps1`
  - `scripts/restore_supabase_public_backup.ps1`
  - `scripts/build_infraspeak_import_preview.ps1`
- O `.gitignore` passou a ignorar os outputs locais de:
  - `backups/`
  - `imports/`
- Salvaguarda criada antes de qualquer importacao:
  - `backups/supabase/20260403_171305_pre_infraspeak_test/`
  - ficheiros gerados:
    - `public_schema.sql`
    - `public_data.sql`
    - `public_full.dump`
    - `manifest.json`
    - `restore_notes.txt`
- O preview do Excel `C:\Users\pinta\Downloads\undefined.xlsx` foi convertido
  para ficheiros locais em:
  - `imports/infraspeak/20260403_171937_undefined/`
- Resultado do preview:
  - `8` localizacoes normalizadas
  - `38` ativos unicos
  - `38` dispositivos (`Quadro Electrico`)
  - `13` procedimentos
  - `494` associacoes ativo/procedimento
- Ficheiros principais do preview:
  - `locations.csv`
  - `assets.csv`
  - `asset_devices.csv`
  - `procedure_templates.csv`
  - `asset_procedure_assignments.csv`
  - `summary.json`
- Motivo:
  - permitir validar a estrutura `localizacao > ativo > dispositivo /
    procedimento` antes de tocar nos dados remotos
  - garantir que existe um caminho de restauro claro se o teste de importacao
    for aplicado e mais tarde precisarmos de voltar atras
- Validacao:
  - `scripts/backup_supabase_public.ps1` executado com sucesso e gerou dump do
    `public` remoto
  - `scripts/build_infraspeak_import_preview.ps1` executado com sucesso contra
    `undefined.xlsx`
  - nesta sessao nao foi aplicado qualquer import ao Supabase remoto

## Sessao 2026-04-03 Importacao de Teste Infraspeak
- Foi aplicado ao Supabase remoto um teste de importacao do preview Infraspeak
  com merge conservador, mantendo o backup anterior como ponto de retorno
- Novo script:
  - `scripts/import_infraspeak_preview_to_supabase.ps1`
- Ajustes no fluxo de importacao:
  - o script le os CSV gerados em `imports/infraspeak/...`, resolve a empresa
    atual e faz merge de:
    - `locations`
    - `assets`
    - `asset_devices`
    - `procedure_templates`
  - o import reaproveita registos existentes quando encontra correspondencia e
    so cria o que falta
  - nao foram geradas `work_orders` nem importadas as `494` associacoes
    ativo/procedimento, para evitar ruido operacional nesta fase
  - a normalizacao SQL do import passou a usar Unicode escapes em vez de texto
    acentuado literal para ficar robusta em Windows/PowerShell
- Import aplicado a partir de:
  - `imports/infraspeak/20260403_173021_undefined/`
  - ficheiros de apoio gerados:
    - `import_to_supabase.sql`
    - `import_result.txt`
    - `import_result.json`
- Resultado remoto apos o import:
  - `8` localizacoes
  - `38` ativos
  - `38` dispositivos
  - `14` procedimentos no total da empresa
    - `13` vindos do Infraspeak
    - `1` ja existente
- Incidente tratado na mesma sessao:
  - o primeiro import deixou um duplicado entre
    `Stradivarius Forum Coimbra` e `Stradivarius Fórum Coimbra`
  - a causa foi a normalizacao de acentos no SQL gerado
  - foi feita uma fusao segura dos dois ativos:
    - a ordem de trabalho existente foi movida para o ativo canonico
    - o `qr_code` foi preservado
    - o ativo duplicado foi removido
- Motivo:
  - validar na base de dados real a estrutura desejada pelo utilizador:
    `localizacao > ativo > ordens`
  - carregar a estrutura do Infraspeak sem destruir dados manuais ja criados
- Validacao:
  - `scripts/import_infraspeak_preview_to_supabase.ps1` executado com sucesso
    contra `imports/infraspeak/20260403_173021_undefined/`
  - `import_result.txt` confirmou:
    - `5` localizacoes inseridas
    - `32` ativos inseridos
    - `3` ativos existentes atualizados
    - `38` dispositivos inseridos
    - `13` procedimentos inseridos
  - consulta final ao remoto confirmou contagens esperadas e lista final de
    `38` ativos unicos

## Sessao 2026-04-03 Prioridade Alta nas Ordens
- A criacao e edicao de ordens passou a suportar quatro niveis de prioridade:
  `baixa`, `normal`, `alta` e `urgente`
- Ajustes na app:
  - `lib/work_orders/add_work_order_page.dart` ganhou um seletor visual de
    prioridade no formulario de ordem
  - a prioridade passa a ser carregada na edicao e enviada no payload ao criar
    ou atualizar ordens
  - o fluxo de criacao automatica da proxima ordem preventiva passou a herdar a
    prioridade atual
  - `lib/work_orders/work_order_helpers.dart` passou a centralizar:
    - lista de prioridades suportadas
    - normalizacao do valor guardado
    - label amigavel para UI
    - inclusao de `priority` no payload ingles das ordens
  - `lib/services/work_order_offline_service.dart` passou a preservar a
    prioridade quando cria a proxima preventiva
- Ajustes canonicos de base de dados:
  - nova migration versionada:
    `supabase/migrations/20260403191500_work_order_priority_alta.sql`
- Comportamento novo no Supabase:
  - a constraint `work_orders_priority_check` passou a aceitar:
    - `baixa`
    - `normal`
    - `alta`
    - `urgente`
- Motivo:
  - aproximar o formulario de ordens da forma de trabalho pretendida e do
    modelo visual mostrado pelo utilizador
  - permitir distinguir ordens importantes sem marcar tudo como urgente
- Validacao:
  - `dart format` executado com sucesso em:
    - `lib/work_orders/add_work_order_page.dart`
    - `lib/work_orders/work_order_helpers.dart`
    - `lib/services/work_order_offline_service.dart`
  - `npx.cmd supabase db push` aplicou com sucesso a migration
    `20260403191500_work_order_priority_alta.sql`
  - `npx.cmd supabase migration list` confirmou `Local = Remote`
  - consulta direta ao remoto confirmou a constraint com
    `baixa | normal | alta | urgente`
  - `dart analyze` nao foi concluido neste ambiente por voltar a falhar com
    `CreateFile failed 5 (Acesso negado)`

## Sessao 2026-04-03 Importacao das Ordens Infraspeak
- Foi aplicada a fase seguinte do import Infraspeak: criacao das ordens
  preventivas a partir das `494` associacoes ativo/procedimento geradas no
  preview
- Novo script:
  - `scripts/import_infraspeak_work_orders.ps1`
- Comportamento do import:
  - le `asset_procedure_assignments.csv` do preview e resolve o `asset_id` e o
    `procedure_template_id` por nome normalizado
  - cria ordens em `work_orders` com:
    - `status = pendente`
    - `priority = normal`
    - `order_type = preventiva`
    - `title` baseado em `suggested_order_title`
    - `reference` deterministica no formato `IFS-PREV-...`
  - preenche `description` e `comment` com contexto de origem do Infraspeak
  - preserva idempotencia: se o script correr outra vez, nao duplica ordens
- Ficheiros de apoio gerados em:
  - `imports/infraspeak/20260403_173021_undefined/`
  - ficheiros principais:
    - `import_work_orders_to_supabase.sql`
    - `import_work_orders_result.txt`
    - `import_work_orders_result.json`
- Resultado remoto:
  - `494` ordens Infraspeak inseridas
  - `495` ordens totais na empresa apos o import
  - `495` ordens preventivas no total
- Ajuste feito na mesma sessao:
  - o primeiro rerun do script ainda fazia `update` desnecessario em todas as
    ordens porque os procedimentos importados estavam com `steps = []`
  - o script passou a tratar esse caso e ficou com rerun limpo:
    - `work_orders_inserted = 0`
    - `work_orders_updated = 0`
- Motivo:
  - completar a estrutura `localizacao > ativo > ordens` desejada pelo
    utilizador
  - trazer para a app o plano preventivo do Infraspeak sem precisar de criar as
    ordens manualmente
- Validacao:
  - `scripts/import_infraspeak_work_orders.ps1` executado com sucesso contra
    `imports/infraspeak/20260403_173021_undefined/`
  - consulta direta ao remoto confirmou:
    - `495` ordens totais
    - exemplos com `reference = IFS-PREV-...`
    - `status = pendente`
    - `priority = normal`
    - `order_type = preventiva`
  - nova execucao do mesmo script confirmou idempotencia sem novas insercoes nem
    updates

## Sessao 2026-04-03 Publicacao Web e Android
- Foi publicada uma nova versao web e uma nova build Android para permitir ao
  utilizador testar o estado atual da app apos branding, import Infraspeak e
  prioridade `alta`
- Publicacao web:
  - `scripts/deploy_web_netlify.ps1` executado com sucesso
  - deploy de producao Netlify concluido em:
    - `https://cmmscompinta.netlify.app`
- Publicacao Android:
  - `scripts/deploy_android_firebase.ps1` executado com sucesso em modo
    `release`
  - build gerada:
    - versao `1.0.0`
    - build number `260931815`
  - distribuicao concluida no Firebase App Distribution para os testers
    configurados
- Validacao:
  - `flutter build web` executado com sucesso antes do deploy
  - `flutter build apk --release` executado com sucesso
  - Netlify devolveu `Deploy complete` para producao
  - Firebase App Distribution devolveu `uploaded new release 1.0.0 (260931815)
    successfully`

## Sessao 2026-04-03 Reversao das Ordens e Procedimentos Infraspeak
- Foi revertida apenas a camada de sincronizacao de ordens e procedimentos do
  Infraspeak, mantendo a estrutura importada de localizacoes, ativos e
  dispositivos
- Novo script:
  - `scripts/remove_infraspeak_orders_and_procedures.ps1`
- Comportamento da reversao:
  - remove de `work_orders` as ordens importadas com referencia `IFS-PREV-...`
  - remove de `procedure_templates` os `13` procedimentos importados do
    Infraspeak identificados pelo preview e pela descricao de origem
  - preserva os dados estruturais ja mantidos na app:
    - `locations`
    - `assets`
    - `asset_devices`
  - preserva tambem os registos manuais que ja existiam antes do import
- Resultado remoto apos a limpeza:
  - `494` ordens Infraspeak removidas
  - `13` procedimentos Infraspeak removidos
  - estado final:
    - `8` localizacoes
    - `38` ativos
    - `38` dispositivos
    - `1` ordem
    - `1` procedimento
- Ficheiros de apoio gerados em:
  - `imports/infraspeak/20260403_173021_undefined/`
  - ficheiros principais:
    - `remove_infraspeak_orders_and_procedures.sql`
    - `remove_infraspeak_orders_and_procedures_result.txt`
    - `remove_infraspeak_orders_and_procedures_result.json`
- Motivo:
  - voltar ao ponto anterior ao sync de ordens e procedimentos, sem perder o
    mapeamento estrutural do Infraspeak para localizacoes, ativos e dispositivos
- Validacao:
  - `scripts/remove_infraspeak_orders_and_procedures.ps1` executado com sucesso
    contra `imports/infraspeak/20260403_173021_undefined/`
  - o resultado confirmou:
    - `work_orders_deleted = 494`
    - `procedure_templates_deleted = 13`
    - `work_orders_total = 1`
    - `procedure_templates_total = 1`
  - por ser uma alteracao apenas de dados remotos, nao foi necessaria nova
    publicacao web ou Android

## Sessao 2026-04-03 Recuperacao de Password
- Foi acrescentado um fluxo de recuperacao de password para utilizadores que
  se esquecem da credencial de acesso
- Login:
  - `lib/login_page.dart` passou a mostrar a acao
    `Esqueceste-te da palavra-passe?`
  - a acao abre um dialogo simples para pedir o email da conta e dispara o
    email de recuperacao
- Auth:
  - `lib/services/auth_service.dart` passou a expor:
    - `sendPasswordRecoveryEmail(...)`
    - `updatePassword(...)`
  - o registo por email passou tambem a usar o callback publico
    `https://cmmscompinta.netlify.app/` para manter o retorno consistente com o
    fluxo web de autenticacao
  - `lib/config/auth_redirects.dart` centraliza esse callback
- Callback / redefinicao:
  - `lib/main.dart` passou a detetar callbacks web com `type=recovery`
  - nesses casos a app mostra `lib/reset_password_page.dart` em vez do fluxo
    normal de login/home
  - o novo ecran permite definir a nova palavra-passe, confirmar, concluir a
    sessao recuperada e limpar o URL do callback no browser atraves de:
    - `lib/services/browser_url_service.dart`
    - `lib/services/browser_url_service_web.dart`
    - `lib/services/browser_url_service_stub.dart`
- Documentacao:
  - `README.md` passou a documentar o fluxo e a dependencia do dominio publico
    de auth
- Importancia:
  - fecha uma lacuna critica de autenticacao para contas reais
  - reduz suporte manual quando um utilizador perde acesso por esquecimento da
    password
- Validacao:
  - `dart format` executado com sucesso nos ficheiros alterados
  - `flutter build web` executado com sucesso apos a implementacao
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - `dart analyze` voltou a falhar neste ambiente com
    `CreateFile failed 5 (Acesso negado)`

## Sessao 2026-04-03 Publicacao Recuperacao de Password
- Foi publicada a app com o novo fluxo de recuperacao de password para web e
  Android
- Publicacao web:
  - `scripts/deploy_web_netlify.ps1` executado com sucesso
  - deploy de producao concluido em:
    - `https://cmmscompinta.netlify.app`
  - deploy unico desta publicacao:
    - `https://69d0117cac93ac4e83af8238--cmmscompinta.netlify.app`
- Publicacao Android:
  - `scripts/deploy_android_firebase.ps1` executado com sucesso em modo
    `release`
  - build gerada:
    - versao `1.0.0`
    - build number `260931914`
  - distribuicao concluida no Firebase App Distribution para os testers
    configurados
  - link de teste:
    - `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/0lg3kb886iaqg?utm_source=firebase-tools`
- Validacao:
  - `flutter build web` executado com sucesso no deploy web
  - `flutter build apk --release` executado com sucesso no deploy Android
  - Netlify devolveu `Deploy complete` para producao
  - Firebase App Distribution devolveu `uploaded new release 1.0.0 (260931914) successfully`

## Sessao 2026-04-06 Eliminacao Segura de Tecnicos
- Foi corrigido o fluxo de eliminacao de tecnicos para evitar erro de chave
  estrangeira quando existem registos associados
- App:
  - `lib/services/managed_account_service.dart` passou a expor um preview de
    impacto (`admin_preview_technician_delete`) e a receber um resumo do delete
  - `lib/technicians_page.dart` passou a:
    - pedir o impacto antes de abrir a confirmacao
    - avisar quantas ordens ficam sem tecnico
    - avisar quantos ativos ficam sem tecnico predefinido
    - avisar quantos planeamentos diarios do calendario vao ser removidos
    - mostrar mensagem final com o resumo da limpeza aplicada
  - `lib/users_page.dart` passou a usar o mesmo fluxo quando se elimina um
    utilizador do tipo tecnico
- Backend / SQL:
  - `SUPABASE_MANAGED_ACCOUNT_FLOW.sql` passou a incluir
    `public.admin_preview_technician_delete(uuid)`
  - `public.admin_delete_technician_bundle(uuid)` deixou de devolver `void` e
    passou a devolver um resumo `jsonb`
  - o delete do tecnico limpa agora:
    - `work_orders.technician_id -> null`
    - `assets.default_technician_id -> null`
    - `planned_day_assets` do tecnico -> `delete`
  - migration nova criada em:
    - `supabase/migrations/20260406112000_technician_delete_cleanup_preview.sql`
- Importancia:
  - deixa de haver falha ao apagar tecnicos com ordens, ativos por defeito ou
    planeamento diario associado
  - o utilizador recebe um aviso explicito do impacto antes de confirmar
- Validacao:
  - `dart format` executado com sucesso nos ficheiros Dart alterados
  - `flutter build web` executado com sucesso
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - `dart analyze` voltou a falhar neste ambiente com
    `CreateFile failed 5 (Acesso negado)`
  - `npx supabase migration list` confirmou a migration nova como pendente no
    remoto
  - `npx supabase db push` falhou nesta sessao por falta de credenciais
    operacionais (`SUPABASE_DB_PASSWORD` / `SUPABASE_ACCESS_TOKEN`), por isso a
    parte SQL ficou preparada no repositorio mas ainda nao aplicada ao remoto

## Sessao 2026-04-06 Aplicacao Remota da Correcao e Publicacao
- A correcao da eliminacao de tecnicos foi aplicada no Supabase remoto depois
  de fornecer as credenciais operacionais necessarias
- O utilizador executou com orientacao passo a passo:
  - autenticacao do Supabase CLI com `SUPABASE_ACCESS_TOKEN`
  - ligacao ao projeto com `SUPABASE_DB_PASSWORD`
  - `npx supabase db push`
  - `npx supabase migration list`
- Resultado confirmado pelo utilizador:
  - migration `20260406112000_technician_delete_cleanup_preview.sql`
    aplicada com sucesso no remoto
  - publicacao web concluida
  - publicacao Android concluida
- Estado esperado apos a publicacao:
  - ao eliminar um tecnico, as ordens associadas ficam sem tecnico
  - os ativos com `default_technician_id` desse tecnico ficam sem tecnico
    predefinido
  - os `planned_day_assets` desse tecnico sao removidos
  - antes de confirmar, a app mostra um aviso com o impacto dessa limpeza
- Nota operacional:
  - por seguranca, a password da base de dados e o token pessoal da Supabase nao
    devem voltar a ser colados no historico da conversa

## Sessao 2026-04-06 Definicoes de Conta e Password
- A pagina `Definicoes` passou a incluir uma secao `Conta` visivel para qualquer
  utilizador autenticado
- A nova secao permite:
  - alterar o email de acesso da conta
  - alterar a palavra-passe da conta
  - ver quando existe uma mudanca de email pendente de confirmacao
- App:
  - `lib/settings_page.dart` foi reestruturada para deixar de ser apenas um
    hub administrativo e passou a incluir os dialogos de alteracao de email e
    palavra-passe
  - `lib/home_page.dart` passou a disponibilizar `Definicoes` a todos os
    utilizadores autenticados, para que qualquer conta possa gerir os seus
    dados de acesso
  - `lib/services/auth_service.dart` passou a expor:
    - `updateEmail(...)`
    - `sendPasswordReauthenticationCode()`
    - `updatePassword(..., nonce: ...)`
- Backend / SQL:
  - `SUPABASE_MANAGED_ACCOUNT_FLOW.sql` passou a declarar triggers em
    `auth.users` para manter `public.profiles.email` sincronizado quando o email
    autenticado muda
  - foi criada a migration
    `supabase/migrations/20260406153000_auth_user_profile_email_sync.sql`
- Importancia:
  - o utilizador passa a conseguir gerir o proprio acesso sem depender de um
    admin
  - evita que o email mostrado em `profiles` e na lista de utilizadores fique
    desatualizado depois de uma mudanca de login
- Validacao:
  - `dart format` executado com sucesso nos ficheiros Dart alterados
  - `flutter build web` executado com sucesso
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - `dart analyze` sobre os ficheiros alterados voltou a falhar neste ambiente
    com `CreateFile failed 5 (Acesso negado)`
  - a migration SQL ficou preparada no repositorio, mas ainda nao foi aplicada
    ao Supabase remoto nesta sessao

## Sessao 2026-04-06 Publicacao Web e Android
- Publicacao final do dia executada para disponibilizar as alteracoes recentes
  em web e Android
- Web:
  - deploy de producao concluido em `https://cmmscompinta.netlify.app`
  - deploy unico: `https://69d3fa1fed0f66a8fb708844--cmmscompinta.netlify.app`
- Android:
  - release Firebase App Distribution publicada como `1.0.0 (260961823)`
  - link de teste:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/1tqr1dcmtlc38?utm_source=firebase-tools`
  - distribuida aos testers configurados
- Validacao:
  - `scripts/deploy_web_netlify.ps1` concluido com sucesso
  - `scripts/deploy_android_firebase.ps1` concluiu build release,
    upload, notas de release e distribuicao no Firebase

## Sessao 2026-04-12 Retoma pelo PROJECT_NOTES
- Foi recuperado o contexto recente do projeto a partir do historico registado
  em `PROJECT_NOTES.md`, para retomar o trabalho sem depender da conversa
  anterior
- Estado funcional mais recente confirmado nas notas:
  - a correcao da eliminacao segura de tecnicos ja ficou aplicada no Supabase
    remoto e publicada
  - a pagina `Definicoes` ja inclui gestao de email e palavra-passe para
    qualquer utilizador autenticado
  - a publicacao mais recente registada ficou disponivel em web e Android no
    dia `2026-04-06`
  - a build Android mais recente registada e `1.0.0 (260961823)`
- Ponto de atencao ao retomar:
  - a migration
    `supabase/migrations/20260406153000_auth_user_profile_email_sync.sql`
    ficou preparada no repositorio, mas nas notas ainda nao consta como
    aplicada ao Supabase remoto
- Proximo passo recomendado ao retomar:
  - aplicar essa migration no remoto
  - validar na app a alteracao de email e a sincronizacao de
    `auth.users -> public.profiles.email`
  - confirmar o fluxo de mudanca de palavra-passe em web e Android
- Validacao:
  - ultimas sessoes de `PROJECT_NOTES.md` revistas diretamente
  - estado de retoma consolidado sem alterar comportamento da app nesta sessao

## Sessao 2026-04-12 Nota Audio e Reabertura de Ordens Concluidas
- Foi melhorado o fluxo das ordens de trabalho para o tecnico conseguir
  remover uma nota audio ja gravada e para uma ordem acabada de concluir
  continuar acessivel no dashboard, permitindo voltar a alterar o estado
- App:
  - `lib/work_orders/task_detail_page.dart` passou a mostrar a acao
    `Eliminar` na secao `Nota audio` para tecnicos quando a ordem ja tem audio
  - a eliminacao limpa `audio_note_url` na ordem e para imediatamente a
    reproducao local antes de guardar
  - a atualizacao do estado tecnico continua disponivel e a ordem concluida
    deixa de desaparecer do acesso rapido do dashboard
  - `lib/dashboard_page.dart` passou a mostrar `Ultimas ordens` em vez de
    apenas ordens em aberto, mantendo o contador separado de ordens abertas
- Offline / Storage:
  - `lib/services/work_order_offline_service.dart` passou a suportar limpezas
    adiadas de ficheiros no Storage apos sincronizacao com
    `DeferredStorageDelete`
  - isto cobre tanto a substituicao de uma nota audio antiga por outra como a
    eliminacao da nota audio quando a alteracao fica pendente e sincroniza mais
    tarde
- Importancia:
  - evita que o tecnico fique preso com uma nota audio errada ou desatualizada
  - reduz a sensacao de irreversibilidade depois de concluir uma ordem no
    dashboard
- Validacao:
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - `dart format` e `flutter analyze` nao ficaram concluidos neste ambiente
    porque os comandos do SDK ficaram bloqueados/sem resposta

## Sessao 2026-04-12 Publicacao Web e Android
- Foi publicada a versao atual com os ajustes da nota audio e da reabertura de
  ordens concluidas
- Web:
  - deploy de producao concluido em `https://cmmscompinta.netlify.app`
  - deploy unico:
    `https://69db57e276fa167beddb01a7--cmmscompinta.netlify.app`
- Android:
  - release Firebase App Distribution publicada como `1.0.0 (261020829)`
  - link de teste:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/0vl2l6iv0eqg0?utm_source=firebase-tools`
  - distribuida aos testers configurados
- Validacao:
  - `scripts/deploy_web_netlify.ps1` concluiu build web e deploy de producao
  - `scripts/deploy_android_firebase.ps1` concluiu build release, upload,
    notas de release e distribuicao no Firebase

## Sessao 2026-04-12 Rebranding do Logo e Icone
- Foi atualizado o branding visual da app para alinhar com o novo logotipo
  horizontal fornecido em `mantra_full.png` e reforcar memoria visual da marca
- Branding / assets:
  - novo logo principal copiado para
    `assets/branding/mantra_full.png`
  - novo simbolo recortado a partir do mesmo logo guardado em
    `assets/branding/mantra_mark_from_full.png`
  - nova fonte quadrada para icones gerada em
    `assets/branding/mantra_icon_square_source.png`
  - `lib/config/branding.dart` passou a apontar para os novos assets
- App:
  - `lib/home_page.dart` passou a mostrar uma versao compacta da marca no
    cabecalho interno, sempre visivel durante a navegacao
  - o logo lateral da shell desktop passou a usar o novo wordmark dentro de um
    suporte claro para manter contraste
  - `lib/login_page.dart`, `lib/account_setup_page.dart` e
    `lib/reset_password_page.dart` passaram a usar `BoxFit.contain` para nao
    cortar o novo logo horizontal
- Icones:
  - `scripts/update_app_icons.ps1` foi executado com a nova fonte quadrada
  - ficaram atualizados os icones de Android, iOS, macOS, Windows e web
- Importancia:
  - unifica a identidade visual entre web, app e iconografia
  - cria presenca consistente da marca no cabecalho sem roubar espaco util
- Validacao:
  - verificacao visual dos assets gerados para web e Android
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso

## Sessao 2026-04-12 Publicacao do Rebranding
- Foi publicada a versao com o novo logotipo no cabecalho e os novos icones
  regenerados para todas as plataformas
- Web:
  - deploy de producao concluido em `https://cmmscompinta.netlify.app`
  - deploy unico:
    `https://69db64613fe211a69e1810ff--cmmscompinta.netlify.app`
- Android:
  - release Firebase App Distribution publicada como `1.0.0 (261020922)`
  - link de teste:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/6rqsoob1jfbj8?utm_source=firebase-tools`
  - distribuida aos testers configurados
- Validacao:
  - `scripts/deploy_web_netlify.ps1` concluiu build web e deploy de producao
  - `scripts/deploy_android_firebase.ps1` concluiu build release, upload,
    notas de release e distribuicao no Firebase

## Sessao 2026-04-12 Resumo Diario IA
- Foi integrado um MVP de resumo operacional diario no dashboard para admins,
  com backend dedicado no Supabase e fallback local quando a chave OpenAI nao
  estiver configurada
- App:
  - `lib/dashboard_page.dart` passou a mostrar o painel `Resumo do dia` para
    admins, com acao manual para gerar ou atualizar o resumo
  - `lib/models/daily_ai_summary.dart` e
    `lib/services/daily_ai_summary_service.dart` passaram a estruturar o
    payload, os indicadores e a chamada da Edge Function
  - o painel mostra headline, secoes de feito / por concluir / bloqueios /
    atencao para amanha, alem de indicadores operacionais resumidos
- Supabase:
  - nova migration
    `supabase/migrations/20260412113000_daily_ai_summaries.sql` criou a tabela
    `daily_ai_summaries`, indices, checks, RLS admin-only e trigger de
    `updated_at`
  - nova Edge Function `daily-operations-summary` passou a recolher planeamento
    diario, ordens com atividade e backlog aberto, gerar resumo com OpenAI
    quando disponivel e guardar o resultado na tabela
  - `supabase/functions/_shared/email_provider_oauth.ts` passou a aceitar uma
    mensagem customizavel na validacao admin para reutilizar o helper sem texto
    especifico de email
  - `supabase/functions/README.md` foi atualizado com a nova function e as
    env vars opcionais `OPENAI_API_KEY` / `OPENAI_DAILY_SUMMARY_MODEL`
- Importancia:
  - cria um ponto unico no dashboard para o admin perceber o estado do dia sem
    ter de percorrer ordens e planeamento manualmente
  - deixa a base preparada para evoluir de resumo manual para geracao
    automatica mais tarde
- Validacao:
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - deploy da Edge Function `daily-operations-summary` concluido no projeto
    Supabase `uaupakkizxmwgcfrtnnz`
  - `supabase db push` aplicou a migration nova e, no mesmo fluxo, a migration
    pendente `20260406153000_auth_user_profile_email_sync.sql`
  - `flutter analyze` / `dart analyze` continuaram sem resposta neste ambiente

## Sessao 2026-04-12 Publicacao do Resumo Diario
- Foi publicada a versao com o painel de resumo diario no dashboard e o backend
  associado ficou ativo no Supabase remoto
- Web:
  - deploy de producao concluido em `https://cmmscompinta.netlify.app`
  - deploy unico:
    `https://69db764a205345c19054bd71--cmmscompinta.netlify.app`
- Android:
  - release Firebase App Distribution publicada como `1.0.0 (261021034)`
  - link de teste:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/5aic75rhnl3n8?utm_source=firebase-tools`
  - distribuida aos testers configurados
- Backend:
  - migration `20260412113000_daily_ai_summaries.sql` aplicada no Supabase
    remoto
  - function `daily-operations-summary` publicada com sucesso
- Validacao:
  - `scripts/deploy_web_netlify.ps1` concluiu build web e deploy de producao
  - `scripts/deploy_android_firebase.ps1` concluiu build release, upload,
    notas de release e distribuicao no Firebase

## Sessao 2026-04-12 Hotfix verify_jwt do Resumo Diario
- Foi corrigida a configuracao da Edge Function `daily-operations-summary`
  para evitar o erro de gateway `Invalid JWT` ao gerar o resumo a partir da app
- Backend:
  - `supabase/config.toml` passou a incluir
    `[functions.daily-operations-summary] verify_jwt = false`
  - `supabase/functions/README.md` foi alinhado com a regra usada nesta
    function
  - a function `daily-operations-summary` foi republicada no projeto Supabase
- Importancia:
  - o erro mostrado na app deixava a geracao do resumo bloqueada apesar da
    sessao do utilizador estar valida
- Validacao:
  - `curl -X POST` para a function publicada passou a responder
    `{"error":"Missing Authorization header."}`, confirmando que o gateway
    deixou de barrar a chamada antes de chegar ao codigo da function

## Sessao 2026-04-12 Assinatura Mobile e Ideia do Agente Tecnico
- Foi ajustada a shell mobile para a referencia
  `created and developed by Micael Cunha` ficar visivel tambem na app Android,
  de forma discreta e sem ocupar area util
- App:
  - `lib/home_page.dart` passou a reutilizar a assinatura existente da sidebar
    desktop tambem no rodape da navegacao mobile, com tipografia pequena e
    alinhamento discreto
- Publicacao:
  - web publicada em `https://cmmscompinta.netlify.app`
  - deploy unico:
    `https://69dbe6f0fd1847609c75ec34--cmmscompinta.netlify.app`
  - Android Firebase publicado como `1.0.0 (261021836)`
  - link testers:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/3enr83ivep560?utm_source=firebase-tools`
- Ideia futura registada para continuidade:
  - evoluir o agente IA de resumo para um copiloto operacional lado a lado com
    o tecnico durante a execucao da ordem
  - objetivo futuro: lembrar evidencias e recolha estruturada no momento certo,
    com prompts como `tira foto`, `usaste material?`, `houve bloqueio?`, em vez
    de funcionar apenas como chat generico
- Validacao:
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - `scripts/deploy_web_netlify.ps1` concluiu build e deploy
  - `scripts/deploy_android_firebase.ps1` concluiu build release, upload e
    distribuicao

## Sessao 2026-04-13 Relatorios PDF e Correcao de Email Admin
- Relatorios:
  - `lib/reports_page.dart` passou a incluir filtros de `Ativo` e
    `Equipamento`
  - os novos filtros foram propagados tambem para a pre-visualizacao, CSV e
    PDF do relatorio
  - as listas de ordens do relatorio passaram a mostrar o equipamento
    associado quando existir
- Ordens de trabalho:
  - `lib/work_orders/work_order_pdf_service.dart` foi criado para gerar PDF de
    uma ordem de trabalho
  - `lib/work_orders/task_detail_page.dart` passou a mostrar ao admin uma
    acao de partilha PDF dentro da ordem
  - antes de gerar o PDF, o admin pode agora escolher que secoes incluir
    (resumo, descricao, atribuicao, datas, requisitos, medicao, observacoes,
    procedimento, fotografia e anexos)
- Supabase / contas:
  - `SUPABASE_MANAGED_ACCOUNT_FLOW.sql` passou a preservar o perfil existente
    quando `auth.users` muda de email com metadata incompleto, evitando
    despromover admins para tecnico por engano
  - nova migration
    `supabase/migrations/20260413103000_preserve_profile_role_on_email_change.sql`
    criada para:
    - endurecer `public.handle_new_user()`
    - sincronizar `auth.users.raw_user_meta_data` com `public.profiles`
    - reparar o caso ja afetado da conta que passou para
      `pintadooceano@gmail.com`
  - a migration foi aplicada com sucesso no Supabase remoto
- Importancia:
  - fecha a lacuna pedida nos filtros dos relatorios
  - permite ao admin partilhar uma ordem em PDF de forma controlada e mais
    apresentavel
  - corrige a regressao critica em que a mudanca de email podia retirar o
    acesso administrativo da conta
- Validacao:
  - `dart format` executado com sucesso em:
    - `lib/reports_page.dart`
    - `lib/work_orders/task_detail_page.dart`
    - `lib/work_orders/work_order_pdf_service.dart`
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - `npx supabase migration list` confirmou a migration nova como pendente e,
    depois do push, como aplicada no remoto
  - `npx supabase db push` aplicou com sucesso a migration
    `20260413103000_preserve_profile_role_on_email_change.sql`
  - `flutter analyze` sobre os ficheiros alterados voltou a ficar bloqueado /
    sem resposta neste ambiente

## Sessao 2026-04-13 Publicacao Web e Android
- Foi publicada a versao com:
  - filtros de relatorios por `Ativo` e `Equipamento`
  - partilha PDF configuravel dentro da ordem de trabalho
  - correcao da preservacao do perfil admin na mudanca de email
- Web:
  - deploy de producao concluido em `https://cmmscompinta.netlify.app`
  - deploy unico:
    `https://69dcd81462f20d603f87a59e--cmmscompinta.netlify.app`
- Android:
  - release Firebase App Distribution publicada como `1.0.0 (261031148)`
  - link de teste:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/7j64ke849ag90?utm_source=firebase-tools`
  - distribuida aos testers configurados:
    - `micaelpcunha@gmail.com`
    - `pintadooceano@gmail.com`
- Validacao:
  - `scripts/deploy_web_netlify.ps1` concluiu build web e deploy de producao
  - `scripts/deploy_android_firebase.ps1` concluiu build release, upload,
    notas de release e distribuicao no Firebase

## Sessao 2026-04-13 Hotfix JWT do Onboarding e Recuperacao da Conta Hotmail
- Foi corrigido o fluxo de onboarding / criacao de empresa para evitar erros
  `Invalid JWT` quando a conta autenticada precisa de criar ou ligar uma
  empresa
- App:
  - `lib/services/auth_service.dart` passou a expor
    `refreshSessionIfPossible()`
  - `lib/services/account_setup_service.dart` passou a:
    - tentar refrescar a sessao automaticamente quando encontra erros de JWT
    - repetir uma vez o `fetchCurrentState()` antes de cair no cache
    - repetir uma vez o `account-bootstrap` depois de refrescar a sessao
  - `lib/services/profile_service.dart` passou a repetir a carga do perfil
    depois de refresh automatico quando o erro for JWT invalido
- Supabase:
  - `supabase/config.toml` passou a incluir
    `[functions.account-bootstrap] verify_jwt = false`
  - `supabase/functions/README.md` foi atualizado para documentar essa regra
  - nova migration
    `supabase/migrations/20260413134500_account_bootstrap_jwt_and_hotmail_recovery.sql`
    criada para:
    - reforcar a sincronizacao `auth.users -> public.profiles`
    - recuperar a conta desejada `pintadooceano@hotmail.com` como `admin`
      da empresa correta quando existir no projeto
  - a function `account-bootstrap` foi republicada no projeto Supabase
- Publicacao:
  - a app web foi republicada com o hotfix em `https://cmmscompinta.netlify.app`
  - Android Firebase App Distribution publicado como `1.0.0 (261031211)`
  - link de teste Android:
    `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/25achp93rrli8?utm_source=firebase-tools`
- Importancia:
  - reduz o risco de uma sessao valida cair erradamente em onboarding por
    causa de token antigo / invalido
  - evita o bloqueio do onboarding por `Invalid JWT`
  - alinha a conta pretendida para uso administrativo com
    `pintadooceano@hotmail.com`
- Validacao:
  - `dart format` executado com sucesso nos servicos alterados
  - `flutter test --no-pub test/widget_test.dart` executado com sucesso
  - `npx supabase db push` aplicou com sucesso a migration
    `20260413134500_account_bootstrap_jwt_and_hotmail_recovery.sql`
  - `npx supabase functions deploy account-bootstrap --project-ref uaupakkizxmwgcfrtnnz`
    concluiu com sucesso
  - `npx supabase migration list` confirmou a migration nova como aplicada no
    remoto
  - `scripts/deploy_android_firebase.ps1` concluiu build release, upload,
    notas de release e distribuicao

## Sessao 2026-04-13 Redistribuicao Android Hotmail Pendente
- Foi preparada a configuracao local de testers Android para incluir
  `pintadooceano@hotmail.com`
- A redistribuicao da release Android mais recente ficou pendente porque o
  `FIREBASE_TOKEN` local expirou e esta consola nao suporta o fluxo interativo
  de autenticacao do Firebase
- Tentativas validadas nesta sessao:
  - `firebase-tools login:list` confirmou que nao ha contas autorizadas ativas
  - `firebase-tools login` e `login:ci` nao puderam ser usados neste ambiente
    por falta de interatividade
  - nao foi encontrada nenhuma service account Google pronta a reutilizar nas
    pastas de utilizador verificadas
- Proximo passo:
  - renovar a autenticacao Firebase fora desta consola e repetir
    `scripts/deploy_android_firebase.ps1 -SkipBuild` para distribuir a build
    `1.0.0 (261031211)` tambem para `pintadooceano@hotmail.com`

## Sessao 2026-04-13 Fluxo Android com Sessao Firebase CLI
- O script de distribuicao Android passou a aceitar tres formas de
  autenticacao:
  - `FIREBASE_TOKEN`
  - `GOOGLE_APPLICATION_CREDENTIALS`
  - sessao local ja autenticada do `firebase-tools`
- Ficheiros atualizados:
  - `scripts/deploy_android_firebase.ps1`
  - `scripts/firebase_app_distribution.local.example.ps1`
  - `FIREBASE_APP_DISTRIBUTION_SETUP.md`
- Importancia:
  - evita bloqueios quando um `FIREBASE_TOKEN` local expira
  - permite reutilizar um `firebase login --reauth` normal na maquina sem
    guardar novos tokens no ficheiro local
- Validacao:
  - `scripts/deploy_android_firebase.ps1 -SkipBuild -SkipDistribute`
    executado com sucesso e confirmou a APK release existente

## Sessao 2026-04-13 Redistribuicao Android Hotmail Concluida
- A release Android existente `1.0.0 (261031211)` foi redistribuida no
  Firebase App Distribution usando a sessao autenticada local do
  `firebase-tools`
- Testers finais desta release:
  - `micaelpcunha@gmail.com`
  - `pintadooceano@gmail.com`
  - `pintadooceano@hotmail.com`
- Link de teste Android:
  - `https://appdistribution.firebase.google.com/testerapps/1:691350615761:android:1b10bc6a2173d0751e77f0/releases/25achp93rrli8?utm_source=firebase-tools`
- Correcao adicional:
  - `scripts/deploy_android_firebase.ps1` passou a reutilizar o ultimo build
    number guardado quando corre com `-SkipBuild`, para nao escrever release
    notes erradas ao redistribuir uma APK ja existente
- Validacao:
  - `npx firebase-tools@latest login:list` confirmou a sessao
    `micaelpcunha@gmail.com`
  - `scripts/deploy_android_firebase.ps1 -SkipBuild` concluiu upload
    reutilizado, distribuicao aos tres testers e reposicao das release notes
    corretas
## Sessao 2026-04-14 Pipeline Remota iOS TestFlight
- Foi preparada a retoma da entrega iOS sem depender de um Mac local recente,
  usando build remoto em `Codemagic`
- Ficheiros atualizados:
  - `codemagic.yaml`
  - `IOS_TESTFLIGHT_SETUP.md`
  - `README.md`
- O workflow remoto `ios-testflight` ficou configurado para:
  - usar `Xcode 26.2.x`
  - aplicar signing `App Store` para `com.micaelcunha.mantra`
  - calcular automaticamente o `build number` a partir do `App Store Connect`
  - gerar `.ipa` assinada e publicar em `App Store Connect`
- Documentacao alinhada com o setup necessario no Codemagic:
  - integracao Apple com o nome `mantra-app-store-connect`
  - grupo de variaveis `ios_remote_release`
  - variavel obrigatoria `APP_STORE_APPLE_ID`
- Nota funcional registada:
  - os links de confirmacao / recuperacao por email continuam a abrir o
    callback web `https://cmmscompinta.netlify.app/` e nao um deep link nativo
    iOS; isto nao bloqueia a primeira entrega via TestFlight, mas ficou
    identificado como melhoria futura para um fluxo 100% nativo
- Validacao:
  - leitura local dos ficheiros iOS / docs atualizados
  - `flutter test --no-pub test/widget_test.dart` tentou correr neste ambiente
    Windows, mas voltou a ficar sem resposta / em timeout, pelo que a pipeline
    remota passa a ser o ponto principal de validacao desta fase

## Sessao 2026-04-14 Bootstrap GitHub do Projeto
- Foi iniciado o versionamento Git local do projeto e ligada a origem GitHub
  `https://github.com/micaelpcunha/mantra.git`
- Ajustes feitos:
  - identidade Git local configurada para `mantra <micaelpcunha@gmail.com>`
  - `main` criada como branch inicial do repositorio local
  - `.gitignore` atualizado para ignorar `/.npm-cache/` e `/supabase/.temp/`
- Importancia:
  - deixa o repositorio pronto para `push` no GitHub e para ligar o
    `Codemagic` ao codigo real
  - evita subir artefactos temporarios locais do npm e do Supabase CLI
- Validacao:
  - `origin` configurado para `https://github.com/micaelpcunha/mantra.git`
  - staging local concluido sem incluir `supabase/.temp`
  - `git push -u origin main` concluido com sucesso
  - branch `main` ficou a seguir `origin/main`
