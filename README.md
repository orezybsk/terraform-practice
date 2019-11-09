# terraform-practice
Terraform 練習用レポジトリ

## tfenv のインストール

tfutils/tfenv  
https://github.com/tfutils/tfenv

1. `git clone https://github.com/tfutils/tfenv.git /d/tfenv`
1. 環境変数 PATH に D:\tfenv\bin を追加する。
1. `tfenv`

    ```
    $ tfenv
    tfenv 1.0.2-1-gd227138
    Usage: tfenv <command> [<options>]
    
    Commands:
       install       Install a specific version of Terraform
       use           Switch a version to use
       uninstall     Uninstall a specific version of Terraform
       list          List all installed versions
       list-remote   List all installable versions
    ```

1. `tfenv listremote`
1. `tfenv install 0.12.13`
1. `tfenv list`

    ```
    $ tfenv list
    * 0.12.13 (set by /d/tfenv/version)
    ```
   
1. 別のバージョンに変更するには `tfenv use 0.12.13`

## direnv のインストール

1. https://github.com/direnv/direnv/releases  
    から direnv.windows-amd64.exe をダウンロード
1. `D:\direnv\` の下に direnv.windows-amd64.exe を置く
1. `C:\Users\<Windowsユーザ名>\` の下に .bashrc を作成して以下の内容を記述する

    ```
    alias direnv="/d/direnv/direnv.windows-amd64.exe"
    eval "$(direnv hook bash)"
    ```

1. 環境変数を設定したいディレクトリの下に .envrc を作成して  
    `export AWS_ACCESS_KEY_ID=...` のように設定したい環境変数を記述する
1. Git Bash を起動する（起動している場合には起動し直す）  
    この時 `ARNING: Found ~/.bashrc but no ~/.bash_profile, ~/.bash_login or ~/.profile.`  
    というエラーメッセージが表示され、`C:\Users\<Windowsユーザ名>\` の下に .bash_profile が作成される
1. 環境変数を設定したいディレクトリに移動すれば .envrc に設定された環境変数が設定される  
    ディレクトリから移動すると設定された環境変数は解除される
1. .gitignore に .envrc が対象外になるよう記述を追加する

## 参考資料

* Terraform - AWS Provider  
    https://www.terraform.io/docs/providers/aws/index.html

* 既存のAWS環境を後からTerraformでコード化する  
    https://dev.classmethod.jp/cloud/aws/aws-with-terraform/

* Linux AMI の検索  
    https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/finding-an-ami.html

* TerraformでSecurity Groupを作ったら上手くいかなかった  
    https://dev.classmethod.jp/cloud/aws/my-mistake-about-creating-sg-by-terraform/

* direnv/direnv  
    https://github.com/direnv/direnv

* Windows10・Git bash環境にてdirenvを導入する  
    https://qiita.com/iwaimagic/items/ef99f9444d9d91aea0c3
