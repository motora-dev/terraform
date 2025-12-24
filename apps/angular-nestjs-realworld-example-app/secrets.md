# angular-nestjs-realworld-example-app Secrets

## Required Secrets

This application requires the following secrets to be configured in GCP Secret Manager:

| Secret Name                      | Description                                  |
| -------------------------------- | -------------------------------------------- |
| `realworld-database-url`         | Database connection URL                      |
| `realworld-cors-origins`         | Allowed CORS origins                         |
| `realworld-cookie-domain`        | Cookie domain setting                        |
| `realworld-basic-auth-user`      | Basic authentication username                |
| `realworld-basic-auth-password`  | Basic authentication password                |
| `realworld-isr-secret`           | ISR (Incremental Static Regeneration) secret |
| `realworld-session-secret-token` | Session secret token                         |

## GitHub Repository

- Organization: `motora-dev`
- Repository: `angular-nestjs-realworld-example-app`

## Service Name

`realworld`
