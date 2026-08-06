# Quickshell bar

Waybar の構成を Quickshell 0.3 向けに移植したトップバーです。`shell.qml` は共有サービスと画面ごとの `widgets/Bar.qml` を生成し、各表示機能は `widgets/`、共通表示は `components/`、データ取得は `services/` と `scripts/` に分かれています。

## 操作

- Workspace: 左クリックで移動
- Spotify: 左クリックで再生/一時停止、中クリックで前曲、右クリックで次曲
- Clock: 右クリックで通常表示と代替表示を切り替え
- Brightness: ホイールで1%変更
- Volume: 左クリックで pavucontrol、中/右クリックでミュート、ホイールで1%変更
- Network: クリックで kitty 上の nmtui を起動
- Bluetooth: 左クリックで電源を切り替え
- Tray: 左/中クリック、右クリックメニュー、ホイールを各アプリへ転送

Qt Quick Controls の標準 Tooltip は layer-shell 上で画面入力を遮るため使用していません。各モジュールのクリックとホイール操作を優先しています。

## Spotify Connect

Spotify モジュールは `scripts/spotify/spotawaybar.py` を使用します。資格情報の `.env` と `.spotify-token.json` は Git 管理対象外で、所有者だけが読める権限にします。再認証が必要な場合は次を実行してください。

```sh
python3 ~/.config/quickshell/scripts/spotify/spotawaybar.py auth
```

### Spotifyが表示されない場合

再生中にもかかわらずSpotifyモジュールが表示されない場合は、認証エラーにより非表示になっている可能性があります。特に `scripts/spotify/.spotify-token.json` が存在しない場合は、上記の `auth` コマンドを実行してブラウザでSpotify認証を完了してください。認証後は最大5秒程度で表示が戻ります。

現在の状態は次のコマンドで確認できます。

```sh
python3 ~/.config/quickshell/scripts/spotify/spotawaybar.py status
```

## 確認

```sh
qmllint -I /usr/lib/qt6/qml shell.qml widgets/*.qml services/*.qml components/*.qml
bash -n scripts/*.sh
python3 -m unittest discover -s scripts/spotify -p 'test_*.py'
quickshell --path ~/.config/quickshell
```
