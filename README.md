# FlashAir file downloader
DCIMフォルダにある特定の文字を含むファイルを転送するスクリプト

## 初期設定

### Flashair側
[Flashair Developers: CONFIG](https://flashair-developers.com/ja/documents/api/config)

upload.cgi を使うのでUPLOAD=1を設定する。

STAモードを使う場合はIP_Address, Subnet_Mask を設定するかDHCPの固定払い出しでアドレスを固定する

### カメラ側
Power off タイマーをoffか最長にする

## 使い方
```
$ ruby flashair.rb  -h
flashair.rb [options] <ip addr>
  --remove    {on|off}:on
  --overwrite {on|off}:off
  --prefix    {<output directory's prefix>}
  --file      {<filename regexp>}
```

```
$ ruby flashair.rb  192.168.0.45
download /DCIM/101D3400/DSC_0001.JPG(rm) ==> DCIM_101D3400_DSC_0001.JPG
download /DCIM/101D3400/DSC_0002.JPG(rm) ==> DCIM_101D3400_DSC_0002.JPG
download /DCIM/101D3400/DSC_0003.JPG(rm) ==> DCIM_101D3400_DSC_0003.JPG
download /DCIM/101D3400/DSC_0004.JPG(rm) ==> DCIM_101D3400_DSC_0004.JPG
$
```
ファイル名未指定時はDSCがつくファイルを転送します

## その他
 - 特にエラーハンドリングはしていないので、通信が切れた場合などはstack traceを吐きます
 - 削除時にWRITE PROTECT が ON のまま異常終了する場合があります。
  - 再度実行するとOFFになります。
