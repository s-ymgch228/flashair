## 内容物
 - bin/fa-ls.rb
  - Flashair にあるファイルを ls っぽく参照できるやつ
 - bin/fa-cp.rb
  - ファイルを flashair から ローカルにコピーする
 - bin/fa-rm.rb
  - flashair のファイルを削除する
 - bin/flashaird.rb
  - 正規表現に一致するファイルをローカルへ転送するデーモン

flashair のファイルは絶対パス指定のみ可能
fa-*.rb なスクリプトは、--ip <address> で flashair のIPアドレスを指定する

## FreeNAS で flashaird を使う方法
 1. FreeNAS 上に jail を用意する
 2. ruby がなければ "pkg install ruby" でインストールする
 3. ssmtp を使っているので "pkg install ssmtp" でインストール、vi /usr/local/etc/ssmtp.conf で設定を作る
 4. 適当なところに git clone https://github.com/s-ymgch228/flashair.git する
 5. vi /example/path/flashair/etc/flashaird で etc/flashaird の command のパスを 3. のパスに変更する
 6. vi /example/path/flashair/bin/flashaird.rb で MAIL_FROM を書き換える
 7. vi /example/path/flashair/bin/config.rb に設定を作る。書き方は flashaird.rb に記載
 8. vi /etc/rc.conf に flashaird_enable="YES" を追加する
 9. cp /example/path/flashair/etc/flashaird /usr/local/etc/rc.d/. する
 10. /usr/local/etc/rc.d/flashaird start する
 11. おわり
