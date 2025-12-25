# Terraform Infrastructure

複数のアプリケーションの GCP インフラを一元管理する Terraform リポジトリです。

## 📁 ディレクトリ構造

```
terraform/
├── main.tf                    # メイン設定（単一のtfstate）
├── variables.tf               # 変数定義
├── versions.tf                # プロバイダーバージョン
├── outputs.tf                 # 出力定義
├── environments/              # 環境別設定
│   ├── develop.tfvars         # 開発環境
│   ├── preview.tfvars         # プレビュー環境
│   └── main.tfvars            # 本番環境
├── packages/
│   └── common/                # 共通Terraformモジュール
│       ├── iam/               # サービスアカウント & IAM
│       ├── wif/               # Workload Identity Federation
│       └── cloud-run/         # Cloud Run
└── apps/                      # アプリケーションドキュメント
    ├── angular-nestjs-realworld-example-app/
    │   └── secrets.md
    └── motora-dev/
        └── secrets.md
```

## 🔧 前提条件

- Terraform >= 1.12.0
- Google Cloud CLI

## 🚀 使用方法

### 1. 初期設定

```bash
# Google Cloudにログイン
gcloud auth application-default login

# プロジェクトの設定
gcloud config set project YOUR-PROJECT-ID
```

### 2. Terraform の初期化

```bash
cd terraform
terraform init
```

### 3. Workspace の選択

環境ごとに別の Workspace を使用します：

```bash
# 開発環境
terraform workspace select develop  # または: terraform workspace new develop

# プレビュー環境
terraform workspace select preview

# 本番環境
terraform workspace select main
```

### 4. 実行

```bash
# 開発環境の場合
terraform plan -var-file=environments/develop.tfvars
terraform apply -var-file=environments/develop.tfvars

# プレビュー環境の場合
terraform plan -var-file=environments/preview.tfvars
terraform apply -var-file=environments/preview.tfvars
```

## 📝 環境設定

環境固有の設定は `environments/` に格納されています：

| ファイル         | 説明                        |
| ---------------- | --------------------------- |
| `develop.tfvars` | 開発環境                    |
| `preview.tfvars` | プレビュー/ステージング環境 |
| `main.tfvars`    | 本番環境                    |

サンプルファイルをコピーして値を設定：

```bash
cp environments/develop.tfvars.example environments/develop.tfvars
# develop.tfvars を編集して実際の値を設定
```

## 🏢 管理対象サービス

すべてのサービスは単一の tfstate で管理され、リソースの競合を回避します。
また、**1 環境=1 GCP プロジェクト** という方針で運用されており、`environments/` 以下の tfvars ファイルでプロジェクト ID (`project_id`) を切り替えることで環境分離を実現しています。

```hcl
services = {
  "realworld" = {
    github_org   = "motora-dev"
    github_repo  = "angular-nestjs-realworld-example-app"
    # ...
  }
  "motora-dev" = {
    github_org   = "motora-dev"
    github_repo  = "motora-dev"
    # ...
  }
}
```

## 🔐 シークレットの 2 段階管理

シークレットは 2 段階で管理されています。環境分離がプロジェクト単位で行われているため、環境固有のプレフィックス（L3）は廃止されました。

| レベル               | 命名規則           | 例                       | 用途                                                     |
| -------------------- | ------------------ | ------------------------ | -------------------------------------------------------- |
| **L1: グローバル**   | `{name}`           | `basic-auth-user`        | 全サービス共通。<br>環境固有の値であっても名前は共通化。 |
| **L2: サービス共通** | `{service}-{name}` | `realworld-database-url` | サービス固有。<br>他サービスとの名前衝突を避けるため。   |

### シークレット値の設定

環境（GCP プロジェクト）ごとに、以下のコマンドで値を設定します。

```bash
# L1: グローバルシークレット（例: Basic認証ユーザー）
# global_secret_names に定義されているもの
echo -n "YOUR_VALUE" | gcloud secrets versions add basic-auth-user --data-file=-

# L2: サービス固有シークレット（例: DB接続URL）
# secret_names に定義されているもの（Terraformが自動的にサービス名をプレフィックスとして付与）
echo -n "YOUR_VALUE" | gcloud secrets versions add realworld-database-url --data-file=-
```

## 📦 モジュール

### IAM (`packages/common/iam`)

以下のサービスアカウントを作成します：

- GitHub Actions（CI/CD 用）
- Cloud Run（アプリケーション実行用）

### WIF (`packages/common/wif`)

GitHub Actions からの安全な認証のための Workload Identity Federation を設定します。

### Secrets

Google Secret Manager でシークレットを管理します。`main.tf` 内で L1 (グローバル) と L2 (サービス固有) のリソースを一括定義しています。

### Cloud Run (`packages/common/cloud-run`)

Cloud Run サービスを管理します。

## 📤 出力値

適用後、GitHub Actions の設定に必要な出力値を取得できます：

```bash
# すべての出力値を取得
terraform output

# 特定サービスのGitHub Secrets設定を取得
terraform output -json github_secrets_setup | jq '.realworld'

# Cloud Run URLを取得
terraform output cloud_run_urls
```

## 🔒 セキュリティ考慮事項

1. **terraform.tfvars ファイルは絶対にコミットしない**

   - `.gitignore`に含まれています
   - 機密情報が含まれる可能性があります

2. **状態ファイルの管理**

   - 本番環境ではリモートバックエンド（GCS）の使用を推奨

3. **最小権限の原則**
   - 各サービスアカウントには必要最小限の権限のみ付与

## 📚 参考リンク

- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Cloud Run with Terraform](https://cloud.google.com/run/docs/terraform)
