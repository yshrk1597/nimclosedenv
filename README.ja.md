# nimclosedenv
nim の閉鎖環境構築コマンド

[README(English)](/README.md) 

# 概要
* nim を特定ディレクトリで(なるべく)完結させる環境を構築するためのセットアップコマンドです
* python の venv のような activate, deactivate コマンドを提供します
* 現在対応しているのは **Windows(64bit)** のみ

## なぜ仮想環境ではなく閉鎖環境なのか？
nim は内部の環境変数に基づいたディレクトリの使い方が、単純には各環境ごとの安全性を保てないように感じました。

例えば
* デフォルトのnimcacheが、「%USERPROFILE%/nimcache/*プロジェクト名\_d*」もしくは「%USERPROFILE%/nimcache/*プロジェクト名\_r*」

  →スクリプト名が同一でnimコマンドで直接コンパイルしようとしたら同じnimcacheディレクトリを利用することになる？
* pythonのvenvがpipでパッケージをインストールする場合その仮想環境にインストールされるように、nimbleでパッケージをインストールする際もその環境のみにインストールされるようにしたい。

  →環境ごとに環境変数NIMBLE_DIRを設定しないといけない

* nimbleがテンポラリディレクトリを利用する(%TEMP%/nimblecache/*プロジェクト名\_ハッシュ値*)

  →(テスト目的など)違う環境の同名プロジェクトでnimbleを使ってビルドする際、ハッシュ値がかぶってしまう可能性がなくはない

これらを踏まえまして
* 環境下のディレクトリのみで(なるべく)完結させるようにする
* nim が参照するディレクトリパスを設定した環境変数はなるべく環境下のディレクトリになるように変更する
  * nimble によるパッケージインストール先
  * テンポラリディレクトリ
  * デフォルトの nimcache ディレクトリ
* nim や mingw64 も基本は公式サイトよりダウンロードして環境下のディレクトリにインストールする。（マシンにインストール済みのものを利用することも可能）

という対応を行うことにしました。

ただし、3番目の「デフォルトの nimcache ディレクトリ」を変えるために環境変数USERPROFILEを書き換える必要があり、それに伴う副作用が発生する可能性があります。（特に外部コマンド呼び出しで）

# 閉鎖環境ディレクトリレイアウト
<table>
<tbody>
<tr><td>-</td><td colspan=2>topdir/</td><td>閉鎖環境のトップディレクトリ</td></tr>
<tr><td></td><td>-</td><td colspan=1>home/</td><td>環境変数USERPROFILEにこのディレクトリをセットする</td></tr>
<tr><td></td><td>-</td><td colspan=1>mingw64/</td><td>mingw を環境下にインストールする場合はここにインストールされる</td></tr>
<tr><td></td><td>-</td><td colspan=1>nim/</td><td>nim を環境下にインストールする場合はここにインストールされる</td></tr>
<tr><td></td><td>-</td><td colspan=1>nimble/</td><td>nimble パッケージをインストールするためのディレクトリ</td></tr>
<tr><td></td><td>-</td><td colspan=1>projects/</td><td>開発用ディレクトリ</td></tr>
<tr><td></td><td>-</td><td colspan=1>scripts/</td><td>閉鎖環境用スクリプトを置くためのディレクトリ</td></tr>
<tr><td></td><td>-</td><td colspan=1>temp/</td><td>テンポラリディレクトリ</td></tr>
</tbody>
</table>

# 提供スクリプトで書き換えている環境変数
* PATH
* NIMBLE_DIR
* TEMP
* USERPROFILE

# インストール方法
GitHubの本プロジェクトのReleaseページからバイナリパッケージをダウンロードして展開してください。

ただし、2020年8月現在コードサイニング証明書をつけてませんのでダウンロードの際、「**警告**」が出るかと思います。

# 使い方
```
nimclosedenv.exe [オプション] 環境名
```
カレントディレクトリに指定した環境名のディレクトリを作成して環境を構築(もしくは更新)します。
オプションは以下の通りです。
```
  --clean
    既存の環境(ディレクトリ)があれば削除してから構築します。
    デフォルト: false
  --nim:(nimVersion|URL|localNimDirectory)
    バージョン番号かlatestをセットした場合は、環境下にnimをインストールします。
    既にインストール済みのnimを使いたい場合は、そのインストールパスをセットします。
    例
      --nim:latest
        環境下にnimをインストールします。ダウンロードしてくるバージョンはこのアプリのバージョンに依ります。
        末尾のリビジョン番号が10204ならnim-1.2.4をダウンロードします。
      --nim:1.2.4
        環境下に指定したバージョンのnimをインストールします。ただしこのアプリのバージョンが把握していないnimのバージョンは指定できません。
      --nim:https://nim-lang.org/download/nim-1.2.4_x64.zip
        環境下にurlで指定したnimをダウンロードしてインストールします。新しいバージョンをインストールしたい場合はこちらを使うことになります。
      --nim:C:\Users\username\nim-1.2.6
        既にインストール済みのnimを使うようにします。指定するパスはフルパスでなければなりません。  
        ※環境下にインストールはしません
    デフォルト: latest
  --mingw:localMingwDirectory
    既にインストール済みのmingwを使うようにします。そのインストールパスをフルパスでセットします。
    ※セットした場合環境下にインストールはしません
    デフォルト: "" # 空文字列の意味は、環境下にmingwをインストールすることを意味します
  --updateAll
    このオプションは "--updateNim" と "--updateScripts" と "--updateMingw" をまとめてセットします
    デフォルト: false
  --updateNim
    既存の環境で環境下にnimをインストールされていた場合nimを更新します。
    ただし--nimオプションでローカルのnimのパスを指定した場合はこのオプションを無視します。
    デフォルト: false
  --updateScripts
    既存の環境で環境下のスクリプトを更新します。
    デフォルト: false
  --updateMingw
    既存の環境で環境下にmingwをインストールされていた場合mingwを更新します。
    ただし--mingwオプションでローカルのmingwのパスを指定した場合はこのオプションを無視します。
    デフォルト: false
```

## Windows Terminal & PowerShell で閉鎖環境起動のショートカットを作成
activate済みのターミナルを起動できるようにするには以下のようにします。
1. Windows Terminal をインストール
   
   Microsoft Storeからインストールするのが手っ取り早いです。
1. PowerShell のインストール
   
   https://docs.microsoft.com/ja-jp/powershell/ に従ってインストールしてください。
1. Windows Terminal のショートカットを作成し、ショートカットを以下のように編集します。
   * リンク先
     ```
     ～\wt.exe new-tab -d "." pwsh -NoExit scripts\activate.ps1
     ```
   * 作業フォルダー
     ```
     作成した閉鎖環境のフルパス
     ```

## 閉鎖環境化でのVisualStudioCodeの起動
準備として既存のVisualStudioCodeの環境を利用するためにリンクを張ります。
1. 管理者権限でコマンドプロンプトを開き以下のコマンドを実行
    ```
    cd 閉鎖環境ディレクトリ\home
    mklink /d .vscode C:\Users\ユーザー名\.vscode
    ```
VisualStudioCodeの起動は前述の閉鎖環境をWindows Terminal & PowerShellで起動した上で
以下のコマンドを実行すれば起動できます。
```
code
```

# ビルド方法
基本方針として、なるべくdllに依存しない単独で動くexeを生成させることを目的としています。
1. 依存するnimbleパッケージのインストール
   1. nim7zのインストール
      
      2020年7月現在、プルリクエストがまだ取り込まれてないためカスタムのnim7zをインストールします
      ```
      cd temp
      git clone --depth 1 https://github.com/yshrk1597/nim7z
      cd nim7z
      nimble setup
      nimble install
      ```
   1. それ以外のパッケージのインストール
      
      zip, progress, regexのパッケージをインストールします
      ```
      nimble install zip
      nimble install progress
      nimble install regex
      ```
1. zlib のソースコードのダウンロード&展開
   
   Windows で zip パッケージを利用するには zlib をコードごとビルドする必要があるのでsrcディレクトリー以下に展開しておきます。

   http://zlib.net/ よりソースコードをダウンロードしてください。 
   
   2020年7月現在の最新バージョンは1.2.11で、src/zlib-1.2.11 として展開されることを想定しています。
1. openssl をスタティックリンクしたい場合 (optional)
   1. openssl のソースコードのダウンロード&展開
      
      https://www.openssl.org/ よりソースコードをダウンロードし、srcディレクトリー以下に展開しておきます。
      
      2020年10月現在の最新バージョンは1.1.1hで、src/openssl-1.1.1h として展開されることを想定しています。
   1. VisualStudio2019 のインストール
      
      https://visualstudio.microsoft.com/ja/ からVisualStudio2019をダウンロード、インストールしてください。

      インストールの際はワークロードの「C++によるデスクトップ開発」にチェックをいれてください。
   1. perl のインストール
      
      http://strawberryperl.com/ から Strawberry Perlをダウンロード、インストールしてください。(msi版でもポータブル版でもどちらでも可)

   1. task/buildsetup-openssl.bat の実行
      
      opensslをスタティックリンクするために、makefileとヘッダーファイルを生成させないといけません。
      
      上記のバッチコマンドを実行することで生成できます。(エクスプローラーからダブルクリックで実行してOK)
      
      実行前にバッチコマンドの中身を確認、編集してください。(VisualStudioのEditionによるインストール先の違いや、環境変数PATHにstrawberryperlへのパスが通す必要があるか、など)
1. task/constparameter.nim の書き換え
   
   zlib と openssl の展開したパスを設定する変数を書き換えます。srcディレクトリからの相対パスです。

1. task/generate_staticlink_code.nims の実行

   zlib と openssl をスタティックリンクするためのnimのコードを生成します。
   ```
   cd task
   nim generate_staticlink_code.nims
   ```
   実行すると src/generatedcode/staticlink.nim を生成します。
1. task/generate_override_openssl_nim.nims の実行 (optional)
   
   openssl をスタティックリンクするために標準ライブラリの openssl.nim を書き換えます。
   ```
   cd task
   nim generate_override_openssl_nim.nims
   ```
   実行すると src/overridestdlib/openssl.nim を生成します。
1. ビルド
   ```
   nimble build
   ```
   もしくは
   ```
   nimble build -d:release
   ```
   を実行してください。 output ディレクトリに nimclosedenv.exe が出力されます。

# ライセンス
このソフトウェア自体のライセンスはMITライセンスです。

GitHub上のソースコードパッケージとバイナリーパッケージには依存するライブラリのライセンスファイルを追加しています。(thirdparty-licensesディレクトリーにあります)

# その他
## ソースコードパッケージについて
7zがLGPLのため、バイナリーパッケージをビルドの際に利用したnim7zパッケージ(7zのコード含む)、zlib及びopensslのコードを含んでいます。

