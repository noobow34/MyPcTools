
function WaitForMountG {
    param (
        [int]$Timeout = 300,  # タイムアウト秒数（デフォルト60秒）
        [int]$Interval = 5   # チェック間隔（デフォルト5秒）
    )
    
    $Elapsed = 0
    $DriveLetter = "G:"
    
    Write-Host "Gドライブの接続を待機しています..."
    
    while ($Elapsed -lt $Timeout) {
        if (Test-Path $DriveLetter) {
            Write-Host "Gドライブが接続されました。"
            return
        }
        
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
    }

    Write-Host "タイムアウトしました。Gドライブが見つかりませんでした。"
    exit 1    
}

#appsettings.jsonのバックアップ
function AppesttingsBackup {
    $rootPath = "C:\dev"
    $excludedFolders = @("packages", ".git", ".vs", "bin", "obj")
    
    # Get-ChildItemでフォルダを再帰的に検索し、指定された条件でフィルタリング
    Get-ChildItem -Path $rootPath -Recurse -File -Filter "appsettings.json" |
    Where-Object {
        # ファイルのディレクトリパスに含まれるフォルダが除外対象でないことを確認
        $filePath = $_.FullName
        foreach ($excludedFolder in $excludedFolders) {
            if ($filePath -match "\\$excludedFolder\\") {
                return $false
            }
        }
        return $true
    } | ForEach-Object {
        # 結果を表示
        $copyOrigin = $_.FullName
        $spPath = $copyOrigin.Split("\")
        $parentFolder = $spPath[$spPath.Length-2]
        $cpFileName = $parentFolder + "_appsettings.json"
        $destFullPath = "G:\マイドライブ\環境バックアップ\" + $cpFileName
        $cpFileName
        Copy-Item -Path $copyOrigin -Destination $destFullPath
    }    
}

# Gドライブ接続待ち
WaitForMountG

Set-PSDebug -Trace 1
# Tree コマンドの結果 (Cドライブ)
$treeC = tree c:\ /F | findstr /R /C:"^├" /C:"^│  ├" /C:"^│  └" /C:"^└"
Set-Content -Path "G:\マイドライブ\環境バックアップ\Cドライブツリー.txt" -Value $treeC

# Winget アプリ一覧
$wingetList = winget list
Set-Content -Path "G:\マイドライブ\環境バックアップ\アプリ一覧.txt" -Value $wingetList

# Tree コマンドの結果 (ユーザーツリー)
$userTree = tree C:\Users\skywi /F | findstr /R /C:"^├" /C:"^│  ├" /C:"^│  └" /C:"^└"
Set-Content -Path "G:\マイドライブ\環境バックアップ\ユーザーツリー.txt" -Value $userTree

# ユーザースタートメニュー
$userStartMenu = tree "C:\Users\skywi\AppData\Roaming\Microsoft\Windows\Start Menu" /F
Set-Content -Path "G:\マイドライブ\環境バックアップ\ユーザースタートメニュー.txt" -Value $userStartMenu

# All Users スタートメニュー
$allStartMenu = tree "C:\ProgramData\Microsoft\Windows\Start Menu\Programs" /F
Set-Content -Path "G:\マイドライブ\環境バックアップ\Allスタートメニュー.txt" -Value $allStartMenu

# タスクスケジューラーバックアップ
schtasks /query /xml >  G:\マイドライブ\環境バックアップ\task.xml

Set-PSDebug -Trace 0

# appsettings.jsonのコピー
AppesttingsBackup

pause