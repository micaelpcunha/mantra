$env:FIREBASE_APP_ID = 'colar_firebase_app_id_android_aqui'

# Autenticacao opcional:
# 1) token gerado pelo Firebase CLI
$env:FIREBASE_TOKEN = 'colar_firebase_token_aqui'

# 2) ou conta de servico (recomendado para automacao/CI)
# $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\caminho\para\service-account.json'

# 3) ou, se ambos ficarem vazios, o script tenta usar a sessao local
#    do Firebase CLI (ex.: depois de `npx firebase-tools@latest login`)

# Destinatarios opcionais
$env:FIREBASE_TESTERS = 'qa1@empresa.pt,qa2@empresa.pt'
$env:FIREBASE_GROUPS = 'equipa-android'

# Opcional se o Flutter estiver noutro caminho nesta maquina
# $env:FLUTTER_BIN = 'C:\Users\pinta\develop\flutter\bin\flutter.bat'
