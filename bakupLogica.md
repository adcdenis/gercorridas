# Lógica de Backup na Nuvem (Google Drive)

Este documento descreve, de forma completa e atualizada, o funcionamento do backup e restauração de dados na nuvem (Google Drive) do aplicativo.

## Visão Geral

- Implementação principal: `GoogleDriveCloudSyncService` em `lib/data/services/cloud_sync_drive.dart`.
- Interface pública: `CloudSyncService` em `lib/data/services/cloud_sync_service.dart`.
- UI principal: `CloudBackupPage` em `lib/presentation/pages/cloud_backup_page.dart`.
- Providers de estado: `lib/state/cloud_providers.dart`.
- Espaços de armazenamento suportados:
  - `appDataFolder` (privado ao app) quando `useDriveAppDataSpace = true`.
  - Pasta `LembrePlus Backups` no Drive do usuário quando `useDriveAppDataSpace = false`.

## Convenção de Arquivos

- Nome de arquivo de backup: `lembre_backup_YYYYMMDD_HHMMSS.json`.
- O timestamp (UTC) no nome é usado para ordenação lexicográfica e comparação de versões.
- Para exibição na UI, o timestamp é convertido para horário local.

## Persistência de Preferências e Metadados

- Chaves em `SharedPreferences`:
  - `cloud_auto_sync_enabled`: controla se o auto-sync está habilitado.
  - `cloud_last_update_timestamp`: último timestamp conhecido (backup/restauração) usado para evitar restaurações redundantes.
  - `cloud_last_backup_timestamp`: timestamp do último backup criado.
  - `cloud_last_backup_file`: nome do arquivo do último backup criado.
  - `cloud_last_restore_timestamp`: timestamp do último backup restaurado com sucesso.
  - `cloud_last_restore_file`: nome do arquivo restaurado.

## Fluxos de Operação

### Login Manual com Google

- Método: `signInWithGoogle()`.
- Ações:
  - Autentica o usuário via Google Sign-In.
  - Habilita o auto-sync por padrão (`cloud_auto_sync_enabled = true`) e inicia `startRealtimeSync()`.
  - Executa a sincronização de inicialização (`_runStartupAutoSync()`), que verifica e restaura um backup remoto mais recente, se necessário.
  - Não cria backup inicial automaticamente.

### Backup Manual

- Método: `backupNow()`.
- Ações:
  - Serializa o banco local para JSON via `BackupCodec.encodeToJsonString(db)`.
  - Cria o arquivo `lembre_backup_YYYYMMDD_HHMMSS.json` no espaço selecionado (`appDataFolder` ou pasta `LembrePlus Backups`).
  - Persiste metadados:
    - `cloud_last_backup_timestamp` e `cloud_last_backup_file`.
    - Atualiza `cloud_last_update_timestamp` com o mesmo timestamp.
  - Executa limpeza automática via `_cleanupOldBackups()` (mantém apenas os 10 mais recentes).

### Restauração Manual

- Método: `restoreNow()`.
- Ações:
  - Localiza o arquivo de backup mais recente no espaço selecionado.
  - Baixa o JSON e valida via `BackupCodec.validate(...)`.
  - Restaura o banco via `BackupCodec.restore(db, data)`.
  - Persiste metadados:
    - `cloud_last_restore_timestamp` e `cloud_last_restore_file` (com base no nome do arquivo restaurado).
    - Atualiza `cloud_last_update_timestamp` com o timestamp restaurado.
  - Emite evento de restauração (`_restoreCtrl.add(restoredAt)`), consumido pela UI para notificar.
  - Executa limpeza automática via `_cleanupOldBackups()`.

### Restauração Automática no Início

- Método interno: `_runStartupAutoSync()` (chamado no `_bootstrap()` se auto-sync estiver habilitado e usuário autenticado).
- Ações:
  - Lista os arquivos de backup remotos e identifica o mais recente.
  - Compara com `cloud_last_update_timestamp` local.
    - Se o remoto for mais novo, baixa, valida e restaura.
    - Atualiza `cloud_last_update_timestamp` e emite evento de restauração.
  - Executa limpeza automática via `_cleanupOldBackups()`.
  - Erros são tratados silenciosamente para não interromper a inicialização.

### Backup Automático Contínuo

- Métodos: `startRealtimeSync()`, `_onLocalChange()`.
- Ações:
  - Observa `db.watchAllCounters()` e, a cada mudança, aciona um debounce de 20s.
  - Ao término do debounce, executa `backupNow()`.
  - Usado somente quando `cloud_auto_sync_enabled = true`.

#### Supressão após restauração

- Para evitar criar um novo arquivo de backup imediatamente após uma restauração (que altera muitos registros e dispara o observador), existe uma janela de supressão do backup automático.
- Após qualquer restauração bem-sucedida (manual ou automática na inicialização), o serviço ignora mudanças locais para fins de backup por aproximadamente 30 segundos.
- Essa janela cobre o período de debounce e estabilização dos dados restaurados, evitando arquivos redundantes.
 - Se houver alterações locais durante a supressão, um backup automático é agendado imediatamente após o término da janela (sem aguardar o debounce), garantindo que a edição do usuário seja protegida rapidamente.

## Estratégia de Limpeza de Backups

- Método: `_cleanupOldBackups(drive.DriveApi api)`.
- Política: manter no máximo os 10 arquivos mais recentes.
- Funcionamento:
  - Lista até 100 arquivos compatíveis (`mimeType = 'application/json'`, nome contém `lembre_backup_`, `trashed = false`).
  - Caso `useDriveAppDataSpace = false`, filtra pela pasta `LembrePlus Backups`.
  - Ordena por timestamp extraído do nome (lexicográfico decrescente).
  - Exclui do 11º em diante.
  - Log discreto: `debugPrint('[DriveCleanup] Excluído backup antigo: <nome>')`.

## Eventos e UI

- Eventos de restauração:
  - `Stream<DateTime> restoreEvents()` expõe eventos com a data/hora (local) do backup restaurado.
  - Consumido em `AppShell` para mostrar `SnackBar` quando uma restauração ocorre.

- Últimos backup/restauração na tela:
  - Providers:
    - `cloudLastBackupInfoProvider` e `cloudLastRestoreInfoProvider` leem os metadados de `SharedPreferences`.
    - Convertem o timestamp (`YYYYMMDD_HHMMSS`) para `DateTime` local.
  - UI: `CloudBackupPage` exibe:
    - “Último backup: dd/MM/yyyy HH:mm:ss • arquivo: <nome>”.
    - “Última restauração: dd/MM/yyyy HH:mm:ss • arquivo: <nome>”.
  - Atualização imediata após ações manuais:
    - Após `backupNow()`: `ref.invalidate(cloudLastBackupInfoProvider)`.
    - Após `restoreNow()`: `ref.invalidate(cloudLastRestoreInfoProvider)`.
  - Evitar “piscar” desabilitado no Switch de auto-sync:
    - `cloudAutoSyncInitialProvider` lê `cloud_auto_sync_enabled` e fornece valor inicial.
    - O `Switch` usa o valor do stream quando disponível, senão usa o inicial persistido.

## Espaço de Armazenamento

- `useDriveAppDataSpace = true`:
  - Escopos do Google: `email`, `https://www.googleapis.com/auth/drive.appdata`.
  - Dados em `appDataFolder` (não visível ao usuário no Drive).

- `useDriveAppDataSpace = false`:
  - Escopos: `email`, `https://www.googleapis.com/auth/drive.file`.
  - Dados em pasta dedicada `LembrePlus Backups` (criada e gerida automaticamente).

## Tratamento de Erros

- A maioria dos erros é tratada de forma silenciosa em inicialização e no auto-sync para não interromper o uso.
- Durante ações manuais (backup/restauração), erros são reportados via `SnackBar` na UI.
- Validações de JSON antes de restaurar: `BackupCodec.validate(...)`.

## Resumo de Métodos Importantes

- `signInWithGoogle()`: autentica, habilita auto-sync, cria backup inicial e sincroniza timestamp.
- `backupNow()`: cria backup, atualiza metadados e limpa antigos.
- `restoreNow()`: restaura último backup, atualiza metadados, emite evento e limpa antigos.
- `_runStartupAutoSync()`: restauração automática condicional na inicialização.
- `startRealtimeSync()`: observa mudanças e agenda backups com debounce.
- `_cleanupOldBackups()`: mantém apenas os 10 mais recentes.
- `restoreEvents()`: stream de eventos de restauração para UI.

---

Este documento cobre a lógica atual. Ajustes futuros (ex.: retenção configurável, múltiplos perfis de backup, ou notificações mais ricas) podem ser incorporados mantendo as mesmas convenções de timestamp e metadados.