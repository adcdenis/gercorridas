// Configuração de sincronização em nuvem
// Usar Google Drive (sem Firebase)
const bool useGoogleDriveCloudSync = true;

// Nome da subpasta para armazenar backups no Google Drive (My Drive).
// Se preferir deixar oculto fora da raiz, considere usar o espaço appData abaixo.
const String cloudDriveFolderName = 'GerCorridas Backups';

// Usar espaço "appDataFolder" do Google Drive para backups ocultos do app.
// Requer escopo 'https://www.googleapis.com/auth/drive.appdata'.
// Quando true, os backups não aparecerão na raiz do Drive.
const bool useDriveAppDataSpace = false;