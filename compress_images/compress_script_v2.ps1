Start-Transcript -Path "C:\Program Files\compress_images\log.txt" -Append

# Caminho da imagem usada na notificação
$iconPath = [System.IO.Path]::Combine($env:ProgramFiles, "compress_images", "image_notification.jpg")

# Configuração das pastas
$sourceFolder = [System.IO.Path]::Combine($env:ProgramFiles, "compress_images", "image_scan")
$destinationFolder = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("MyDocuments"), "RECEITAS", "SAIDAS A PROCESSAR")

# Verifica se as pastas existem, caso contrário, cria a de destino
if (!(Test-Path -Path $sourceFolder)) {
    Write-Host "Erro: A pasta de origem '$sourceFolder' não existe."
    exit
}

if (!(Test-Path -Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder | Out-Null
}

# Função para aguardar liberação do arquivo
function Wait-ForFileRelease {
    param (
        [string]$filePath,
        [int]$timeout = 10
    )
    
    $elapsed = 0
    while ($true) {
        if (!(Test-Path $filePath)) {
            Write-Host "Erro: Arquivo não encontrado - $filePath"
            return $false
        }

        $output = fsutil file query open "$filePath" 2>&1
        if ($output -match "O processo não pode acessar o arquivo") {
            Start-Sleep -Milliseconds 500
            $elapsed += 0.5
            if ($elapsed -ge $timeout) {
                Write-Host "Erro: Tempo limite atingido para acessar $filePath."
                return $false
            }
        } else {
            return $true
        }
    }
}

# Criar o FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $sourceFolder
$watcher.Filter = "*.*"  # Monitora todos os arquivos
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true
Write-Host "Monitorando a pasta: $sourceFolder"

# Evento de criação de novo arquivo
Register-ObjectEvent $watcher "Created" -Action {
    Start-Sleep 1  # Pequeno delay para garantir que o arquivo está completo
    $filePath = $Event.SourceEventArgs.FullPath
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    $outputFile = "$destinationFolder\$fileName.jpg"

    if (Test-Path $filePath) {
        if (Wait-ForFileRelease -filePath $filePath) {
            # Executa conversão de imagem em paralelo
            Start-Job -ScriptBlock {
                param ($filePath, $destinationFolder)
                & magick mogrify -path "$destinationFolder" -format jpg -quality 20 "$filePath"
                Remove-Item -Path $filePath -Force
            } -ArgumentList $filePath, $destinationFolder

            Import-Module BurntToast
            Remove-BTNotification
            New-BurntToastNotification -Text "Sucesso!", "O arquivo '$fileName', pronto para ser importado." -AppLogo $iconPath
        }
    }
}

# Mantém o script rodando
while ($true) {
    Start-Sleep 10
}

Stop-Transcript
