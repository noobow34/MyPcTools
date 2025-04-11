<#
.SYNOPSIS
指定された単一のネットワークアダプターのDNS設定を対話式で変更するスクリプト。
DNSサーバーの自動取得、またはDNS over HTTPS (DoH) の設定を選択できます。

.DESCRIPTION
このスクリプトは、スクリプト内の定数 $TARGET_INTERFACE_INDEX で指定された
単一のネットワークアダプターに対して、ユーザーの選択に基づいてDNS設定を構成します。
1を選択すると、DNSサーバーアドレスが自動的に取得されるよう設定（DHCP準拠）し、既存のDoH設定もクリアします。
2を選択すると、スクリプト内の定数で指定されたIPv4/IPv6アドレスをDNSサーバーとして設定し、
DNS over HTTPS (DoH) を有効にします（対応するWindowsバージョンのみ）。

設定値（DNSサーバー、DoHテンプレート、対象アダプター）はスクリプト冒頭の定数セクションで変更可能です。

.NOTES
- このスクリプトの実行には管理者権限が必要です。
- DoH設定には、Windows 10 バージョン 2004 (May 2020 Update) 以降、または Windows 11 が必要です。
  対応していない環境でDoH設定を選択した場合、指定されたDNSサーバーアドレスのみが設定されます。
- 設定対象のアダプターの InterfaceIndex を事前に確認し、$TARGET_INTERFACE_INDEX に設定してください。
  (確認コマンド: Get-NetAdapter | Format-Table Name, InterfaceDescription, InterfaceIndex)

.EXAMPLE
# 事前にスクリプト内の $TARGET_INTERFACE_INDEX を設定しておく
.\Set-DnsConfig-SingleAdapter.ps1
プロンプトが表示され、1または2を入力して指定したアダプターのDNS設定を変更します。
#>

#Requires -RunAsAdministrator

# --- 設定値 (ここを編集してください) ---

# 設定対象のネットワークアダプターのインターフェースインデックス
# PowerShellで `Get-NetAdapter | Format-Table Name, InterfaceDescription, InterfaceIndex` を実行して確認し、
# 設定したいアダプターの InterfaceIndex の番号を指定してください。
[int]$TARGET_INTERFACE_INDEX = 9 # <--- ここに対象アダプターのIndex番号を記入してください (例: 6)

# DoHで使用するDNSサーバーのIPv4アドレス (複数指定可能)
# 例: Cloudflare ('1.1.1.1', '1.0.0.1'), Google ('8.8.8.8', '8.8.4.4')
[string]$DOH_IPV4_SERVERS = '138.3.221.196'

# DoHで使用するDNSサーバーのIPv6アドレス (複数指定可能)
# 例: Cloudflare ('2606:4700:4700::1111', '2606:4700:4700::1001'), Google ('2001:4860:4860::8888', '2001:4860:4860::8844')
[string]$DOH_IPV6_SERVERS = '2603:c021:8012:3a7e:451c:b414:6330:e1a5'

# DoHサーバーのURIテンプレート
# 例: Cloudflare ('https://cloudflare-dns.com/dns-query'), Google ('https://dns.google/dns-query')
[string]$DOH_TEMPLATE = 'https://stella2406.dns.noobow.me/dns-query'

# --- 設定値ここまで ---

# $TARGET_INTERFACE_INDEX が初期値(0)のままかチェック
if ($TARGET_INTERFACE_INDEX -eq 0) {
    Write-Error "スクリプト内の `$TARGET_INTERFACE_INDEX` が設定されていません。設定対象のアダプターの InterfaceIndex を指定してください。"
    Write-Host "ヒント: PowerShellで 'Get-NetAdapter | Format-Table Name, InterfaceDescription, InterfaceIndex' を実行して確認できます。"
    exit 1
}


# DoH設定コマンドレットが利用可能かチェック
$isDohAvailable = $false
if (Get-Command Set-DnsClientDohServerAddress -ErrorAction SilentlyContinue) {
    $isDohAvailable = $true
}

# 指定されたアダプターを取得
Write-Host "-------------------------------------------"
Write-Host " DNS設定変更スクリプト (単一アダプター用)"
Write-Host "-------------------------------------------"
Write-Host "設定対象アダプター (Index: $TARGET_INTERFACE_INDEX) を取得中..."
try {
    # 指定されたIndexのアダプターを取得
    $adapter = Get-NetAdapter -InterfaceIndex $TARGET_INTERFACE_INDEX -ErrorAction Stop

    # アダプターが見つかったが、StatusがUpでない場合に警告を出す
    if ($adapter.Status -ne 'Up') {
         Write-Warning "指定されたアダプター (Name: $($adapter.Name)) は存在しますが、現在有効 (Status 'Up') ではありません。設定は試行されますが、意図通りに動作しない可能性があります。"
    }

    Write-Host "設定対象アダプターが見つかりました:"
    $adapter | Format-Table -AutoSize -Property Name, InterfaceDescription, Status, InterfaceIndex
} catch [Microsoft.PowerShell.Commands.GetNetAdapter.NotFoundException] {
    # 指定されたIndexのアダプターが見つからなかった場合のエラー処理
    Write-Error "指定されたインターフェースインデックス ($TARGET_INTERFACE_INDEX) のネットワークアダプターが見つかりませんでした。"
    Write-Host "利用可能なアダプターの一覧:"
    # エラー時にユーザーがIndexを確認しやすいように一覧を表示
    Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, InterfaceIndex
    exit 1
} catch {
    # その他のGet-NetAdapterに関するエラー
    Write-Error "ネットワークアダプターの取得中に予期せぬエラーが発生しました: $($_.Exception.Message)"
    exit 1
}


# ユーザーに選択を促す
Write-Host "-------------------------------------------"
Write-Host "1: DNSサーバーのアドレスを自動的に取得する"
Write-Host "2: DNS over HTTPS (DoH) を設定する"
if (-not $isDohAvailable) {
    Write-Warning "お使いのシステムはDoH設定に完全には対応していません。オプション2を選択した場合、DoHは有効化されませんが、指定されたDNSサーバーアドレスは設定されます。"
}
Write-Host "-------------------------------------------"

# ユーザー入力を取得し検証
$choice = Read-Host "アダプター '$($adapter.Name)' に対する操作番号を入力してください (1 or 2)"
if ($choice -ne '1' -and $choice -ne '2') {
    Write-Error "無効な入力です。'1' または '2' を入力してください。"
    exit 1
}

Write-Host ""
$ifIndex = $adapter.InterfaceIndex
$ifDesc = $adapter.Name # InterfaceDescriptionより短いNameを使用

# 選択に応じて処理を実行
switch ($choice) {
    '1' {
        Write-Host "[選択: 1] アダプター '$ifDesc' のDNSサーバー設定を自動取得に設定します..."
        try {
            # DNSサーバー設定をリセット
            Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ResetServerAddresses -Confirm:$false -ErrorAction Stop
            Write-Host "- DNSサーバーアドレスをリセットしました (自動取得)。"
            Write-Host ""
            Write-Host "アダプター '$ifDesc' のDNS設定の自動取得への変更が完了しました。"
        } catch {
            Write-Warning "アダプター '$ifDesc' の設定変更中にエラーが発生しました: $($_.Exception.Message)"
        }
    }
    '2' {
        Write-Host "[選択: 2] アダプター '$ifDesc' にDNS over HTTPS (DoH) を設定します..."

        # 設定するDNSサーバーアドレスを結合
        $dnsServers = @()
        if ($DOH_IPV4_SERVERS) { $dnsServers += $DOH_IPV4_SERVERS }
        if ($DOH_IPV6_SERVERS) { $dnsServers += $DOH_IPV6_SERVERS }

        if ($dnsServers.Count -eq 0) {
             Write-Warning "設定するDoHサーバーのIPv4またはIPv6アドレスがスクリプト内で定義されていません。処理をスキップします。"
             exit 1
        }
        if (-not $DOH_TEMPLATE -and $isDohAvailable) {
             Write-Warning "DoHテンプレートがスクリプト内で定義されていません。DoH設定はスキップされます。"
             $configureDoh = $false
        } elseif ($isDohAvailable) {
             $configureDoh = $true
        } else {
             $configureDoh = $false # DoHコマンドレットが利用不可
        }

        Write-Host "使用するDNSサーバー: $($dnsServers -join ', ')"
        if ($configureDoh) {
            Write-Host "使用するDoHテンプレート: $DOH_TEMPLATE"
            Write-Host "DoH設定: 暗号化必須、UDPフォールバック無効"
        } else {
            Write-Host "DoH設定は行われません (システム非対応またはテンプレート未指定のため)。"
        }

        # 1. DNSサーバーアドレスの設定
        Write-Host "DNSサーバーアドレスを設定中..."
        try {
            Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $dnsServers -Confirm:$false -ErrorAction Stop
            Write-Host "- DNSサーバーを $($dnsServers -join ', ') に設定しました。"

            # 2. DoHの設定 (利用可能かつテンプレートが指定されている場合)
            if ($configureDoh) {
                 Write-Host "DoH設定を有効化中..."
                 try {
                    Set-DnsClientDohServerAddress -ServerAddress $dnsServers -DohTemplate $DOH_TEMPLATE -AllowFallbackToUdp $false -Confirm:$false -ErrorAction Stop
                    Write-Host "- DoH設定を有効にしました。"
                 } catch {
                    Write-Warning "DoH設定中にエラーが発生しました: $($_.Exception.Message)"
                 }
            }
            Write-Host ""
            Write-Host "アダプター '$ifDesc' の指定されたDNSサーバーアドレスおよびDoHの設定変更が完了しました。"

        } catch {
             Write-Warning "DNSサーバーアドレス設定中にエラーが発生しました: $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "スクリプトの実行が完了しました。"

pause