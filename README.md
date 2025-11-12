# Lembre+

## Resumo do Projeto

O "Lembre+" é um aplicativo de gerenciamento de lembretes desenvolvido em Flutter, projetado especificamente para a plataforma Android. O núcleo do aplicativo é construído em torno de tecnologias modernas do ecossistema Flutter, incluindo:

*   **Gerenciamento de Estado:** Utiliza `flutter_riverpod` para um gerenciamento de estado reativo e escalável.
*   **Navegação:** Emprega `go_router` para uma navegação declarativa e baseada em rotas.
*   **Persistência de Dados:** Usa `Drift` (uma implementação de `Moor`/`SQLite`) para armazenar dados localmente no dispositivo, garantindo que os lembretes sejam salvos de forma segura.
*   **Backup e Sincronização:** Oferece funcionalidades robustas de backup e restauração, permitindo que os usuários exportem seus dados para um arquivo JSON. Além disso, integra-se com o Google Drive para sincronização em nuvem, permitindo backups automáticos e manuais sem depender do Firebase.

A estrutura do projeto é bem definida, separando claramente as camadas de apresentação (telas e widgets), dados (serviços, banco de dados) e estado (providers), o que facilita a manutenção e o desenvolvimento. O aplicativo está configurado para o idioma português do Brasil.

Aplicativo Flutter para gerenciamento de lembretes com navegação moderna, persistência local e suporte a backup/restauração em JSON. O projeto está pronto para distribuição em Android (APK). Plataformas Web e Desktop foram desabilitadas para focar em mobile.

## Estrutura do projeto

```
lembreplus/
├─ lib/
│  ├─ presentation/
│  │  ├─ pages/                # Telas (Home, Backup, Formulários)
│  │  ├─ widgets/              # AppShell (Drawer/NavigationRail), componentes
│  │  └─ navigation/           # Rotas com GoRouter
│  ├─ data/                    # Serviços, banco (Drift), codec de backup
│  ├─ state/                   # Providers (Riverpod)
│  └─ utils/                   # Utilitários diversos
├─ android/                    # Projeto Android (Gradle)
├─ build/                      # Artefatos gerados (após builds)
└─ pubspec.yaml                # Dependências e configurações do Flutter
```

## Instalação

1. Pré-requisitos:
   - `Flutter` 3.24+ (canal stable) e `Dart` 3.8+
   - Android SDK/NDK para build Android

2. Instalar dependências:
   ```bash
   flutter pub get
   ```

3. Rodar em desenvolvimento (Android):
   ```bash
   flutter run -d android
   ```

   Ou utilize o script no Windows para rodar o app em um dispositivo/emulador já iniciado manualmente:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/run_android.ps1
   ```

## Comandos

- `flutter pub get` — instala dependências
- `flutter build apk` — gera APK release em `build/app/outputs/flutter-apk/app-release.apk`

### Notas de build Android

Se houver aviso de NDK, defina a versão no `android/app/build.gradle.kts`:

```kotlin
android {
    ndkVersion = "27.0.12077973"
}
```

## Dependências principais

- `flutter_riverpod` — gerenciamento de estado
- `go_router` — navegação declarativa
- `drift` — ORM/SQL para persistência local
- `sqlite3_flutter_libs` — binários do SQLite
- `path_provider` — diretórios da aplicação
- `shared_preferences` — preferências simples
- `freezed_annotation` + `freezed` — modelos imutáveis e geração de código
- `json_serializable` + `json_annotation` — serialização JSON
- `intl` — internacionalização (ex.: `pt_BR`)
- `file_picker` — seleção de arquivos (web/mobile)
- `fluttertoast` — feedback ao usuário

Dev dependencies:

- `build_runner`, `drift_dev`, `freezed`, `flutter_lints`

<!-- Seção de testes removida: projeto atual não utiliza suite de testes -->

## Backup e restauração

Na aplicação:

- Abra o menu (`Drawer`) e vá em `Backup`
- Exportar: gera arquivo JSON com dados persistidos
- Importar: seleciona um arquivo JSON compatível e restaura dados

Plataformas:

- Android/iOS: o serviço grava/ler do diretório de documentos da aplicação (`getApplicationDocumentsDirectory`) com nome padrão `lembre_backup.json`
  

Codec de backup:

- Suporta `DateTime` tanto em ISO strings quanto em inteiros epoch (compatível com serializer do Drift)

## Artefatos de distribuição

- APK: `build/app/outputs/flutter-apk/app-release.apk`
  
## Sincronização na nuvem (Google) e backup contínuo

Este projeto traz a interface e o serviço de sincronização em nuvem com login Google e backup direto no Google Drive (sem Firebase). Para habilitar a sincronização real entre dispositivos, siga:

1. Habilite a API do Google Drive
   - Acesse o Google Cloud Console no projeto do app.
   - Em `APIs & Services → Library`, ative `Google Drive API`.

2. Configure a tela de consentimento OAuth
   - Em `APIs & Services → OAuth consent screen`, escolha `External`.
   - Adicione escopo `https://www.googleapis.com/auth/drive.file`.
   - Inclua sua conta em `Test users`.

3. Adicione dependências no `pubspec.yaml` (já presentes neste projeto):
   - `google_sign_in`, `http`, `googleapis`.

4. Habilite o provedor Google Drive no código:
   - Em `lib/core/cloud/cloud_config.dart`, `useGoogleDriveCloudSync = true`.

5. Pasta de backups (evitar arquivos na raiz do Drive)
   - Por padrão, os backups são gravados na subpasta `LembrePlus Backups` em "My Drive".
   - Para alterar o nome da pasta, ajuste `cloudDriveFolderName` em `lib/core/cloud/cloud_config.dart`.
   - Se preferir manter os arquivos ocultos fora da raiz do Drive, você pode usar o espaço `appDataFolder`:
     - Em `lib/core/cloud/cloud_config.dart`, defina `useDriveAppDataSpace = true`.
     - Isso muda o escopo de login para `drive.appdata` e os backups ficam acessíveis apenas pelo app.

6. Fluxo no app:
   - Abra `Backup` no menu.
   - Faça login com Google.
   - Ative `Sincronização automática` para manter dados sincronizados entre dispositivos.
   - Comportamento de auto-sync: só envia backup automático ao criar/alterar contadores (com debounce ~20s). Não dispara em eventos de minimizar/fechar o app.
   - Use `Backup na nuvem` e `Restaurar da nuvem` para operações manuais.

Observações:
- Se a Drive API foi ativada recentemente, aguarde alguns minutos para propagação.
- Em Android, garanta que o SHA‑1 do keystore de debug está cadastrado nos `OAuth client IDs` do projeto para que o Google Sign-In funcione.
- O serviço local (`NoopCloudSyncService`) valida o fluxo sem enviar dados.

## Execução somente em dispositivos móveis

Este projeto está configurado para rodar apenas em Android. Inicie manualmente um dispositivo/emulador e rode:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android.ps1
```

Modo release:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android.ps1 -Release
```

Se não houver AVD configurado, crie um emulador no Android Studio (Device Manager) e inicie-o manualmente.

### Executar via VS Code, Gradle ou npm

- VS Code:
  - Paleta de comandos → `Run Task` → selecione `Run Android (dispositivo manual)` ou `Run Android (release, dispositivo manual)`.
  - Arquivo: `.vscode/tasks.json` (já configurado).
- Gradle:
  - `./gradlew runAndroid` (debug)
  - `./gradlew runAndroidRelease` (release)
- npm (atalhos):
  - `npm run android`
  - `npm run android:release`

## Conclusão

Projeto pronto para distribuição. Para publicar:

- Android: assine o APK/AAB com sua keystore e publique na Play Store
  


Gerar APK

- Para um APK de release (instalação manual ou distribuição fora da Play Store):
```
flutter build apk --release
```
- Arquivo gerado: build\app\outputs\apk\release\app-release.apk
- Para um APK de debug (instalação rápida para testes):
```
flutter build apk --debug
```
- Arquivo gerado: build\app\outputs\apk\debug\app-debug.apk
- Para reduzir tamanho (um APK por ABI):
```
flutter build apk --release 
--split-per-abi
```
- Arquivos gerados: build\app\outputs\apk\release\app-*-release.apk (por ABI)
- Abrir a pasta dos APKs no Explorer:
```
explorer .
\build\app\outputs\apk\release
```
AAB (Play Store)

- O formato recomendado para publicação na Play Store:
```
flutter build appbundle --release
```
- Arquivo gerado: build\app\outputs\bundle\release\app-release.aab
Notas rápidas

- Execute flutter doctor para verificar o ambiente Android antes de compilar.
- Para publicar na Play Store, configure assinatura de release (keystore e key.properties ) e a seção de signingConfigs no android/app/build.gradle.kts . Posso te guiar nessa configuração se quiser.

Nota: As plataformas Web e Desktop foram desabilitadas via `flutter config` para garantir execução apenas em dispositivos móveis.


flutter emulators --launch s24
flutter emulators
flutter emulators --create --name s24 
flutter emulators --launch s24 
flutter devices 
flutter run -d emulator-5554 

Rodar flutter pub get e testar no emulador ou dispositivo: flutter run -d emulator-5554 ou flutter run -d android .

flutter build apk --release
