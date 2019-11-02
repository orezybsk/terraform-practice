# terraform-practice
Terraform 練習用レポジトリ

## tfenv のインストール

tfutils/tfenv  
https://github.com/tfutils/tfenv

1. `git clone https://github.com/tfutils/tfenv.git /d/tfenv`
1. 環境変数 PATH に D:\tfenv\bin を追加する。
1. `tfenv`

    > $ tfenv
    > tfenv 1.0.2-1-gd227138
    > Usage: tfenv <command> [<options>]
    > 
    > Commands:
    >    install       Install a specific version of Terraform
    >    use           Switch a version to use
    >    uninstall     Uninstall a specific version of Terraform
    >    list          List all installed versions
    >    list-remote   List all installable versions

1. `tfenv listremote`
1. `tfenv install 0.12.13`
1. `tfenv list`

    > $ tfenv list
    > * 0.12.13 (set by /d/tfenv/version)

1. 別のバージョンに変更するには `tfenv use 0.12.13`
