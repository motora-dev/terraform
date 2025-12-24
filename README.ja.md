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
│       ├── secrets/           # Secret Manager
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

すべてのサービスは単一の tfstate で管理され、リソースの競合を回避します：

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

## 🔐 シークレットの 3 段階管理

シークレットは 3 段階で管理されています：

| レベル               | 命名規則                 | 例                               | 用途                     |
| -------------------- | ------------------------ | -------------------------------- | ------------------------ |
| **L1: グローバル**   | `{name}`                 | `basic-auth-user`                | 全環境・全サービス共通   |
| **L2: サービス共通** | `{service}-{name}`       | `realworld-database-url`         | 全環境共通・サービス個別 |
| **L3: 環境個別**     | `{env}-{service}-{name}` | `develop-realworld-cors-origins` | 環境・サービス個別       |

### シークレット値の設定

```bash
# L1: グローバルシークレット
echo -n "YOUR_VALUE" | gcloud secrets versions add basic-auth-user --data-file=-

# L2: サービス共通シークレット
echo -n "YOUR_VALUE" | gcloud secrets versions add realworld-database-url --data-file=-

# L3: 環境個別シークレット
echo -n "YOUR_VALUE" | gcloud secrets versions add develop-realworld-cors-origins --data-file=-
```

## 📦 モジュール

### IAM (`packages/common/iam`)

以下のサービスアカウントを作成します：

- GitHub Actions（CI/CD 用）
- Cloud Run（アプリケーション実行用）

### WIF (`packages/common/wif`)

GitHub Actions からの安全な認証のための Workload Identity Federation を設定します。

### Secrets (`packages/common/secrets`)

Google Secret Manager でシークレットを管理します（環境・サービスプレフィックス付き）。

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
