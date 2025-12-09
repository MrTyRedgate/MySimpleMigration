# MySimpleMigration

A simple migrations-based Pipeline for Flyway to get started. Use at your own risk, no support provided. Please use in a sandbox environment.

## Overview

This project demonstrates a Flyway **Migrations-based workflow** using Azure DevOps Pipelines. Unlike state-based deployments, this approach uses versioned migration scripts (V1__*, V2__*, etc.) that are applied sequentially to target databases.

## Workflow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Dev Branch    │────▶│  Release Branch │────▶│    Pipeline     │
│                 │ PR  │                 │     │   (Manual)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                               │
        │                                               ▼
        │                                    ┌─────────────────────┐
        │                                    │   1. Authenticate   │
        │                                    ├─────────────────────┤
        │                                    │   2. Build Stage    │
        │                                    │   - Validate        │
        │                                    │   - Clean & Migrate │
        │                                    │   - Publish Scripts │
        │                                    ├─────────────────────┤
        │                                    │ 3. Pre-Deploy Report│
        │                                    │   - Generate Report │
        │                                    │   - Publish Report  │
        │                                    ├─────────────────────┤
        │                                    │ 4. Deploy Target    │
        │                                    │   - Approval Gate   │
        │                                    │   - Execute Migrate │
        │                                    └─────────────────────┘
        │
┌───────▼─────────┐
│ Flyway Desktop  │
│ - Create Schema │
│ - Generate V*   │
│   migrations    │
└─────────────────┘
```

## Developer Workflow

1. **Use Flyway Desktop** to make schema changes in your development database
2. **Generate migration scripts** - Flyway Desktop creates versioned migration files (e.g., `V002__Add_Column.sql`)
3. **Commit to dev branch** - Push migration scripts to version control
4. **Create PR to release branch** - Request merge into the release branch
5. **Pipeline triggers manually** - After PR is merged, manually trigger the pipeline

## Pipeline Stages

### Stage 1: Authenticate
- Authenticates with Redgate using email and PAT token

### Stage 2: Build & Validate
- Displays migration information
- Cleans and migrates to build environment
- Tests undo scripts (rollback)
- Publishes migration scripts as artifact

### Stage 3: Pre-Deployment Report
- Shows pending migrations for target environment
- Generates comprehensive deployment report with:
  - **Changes** - Schema changes to be applied
  - **Drift** - Unexpected differences in target database
  - **Code Analysis** - SQL quality and potential issues
  - **Dry-Run** - Exact SQL script that will be executed
- Publishes deployment report as artifact

### Stage 4: Deploy to MyDeploymentTarget
- **Manual approval gate** - Reviewer must approve deployment
- Executes migrations to target environment
- Verifies deployment status
- Publishes deployment status as artifact

## Prerequisites

### 1. Create Variable Group
Create a variable group named `RG_Auth` in Azure DevOps with:
- `RG_EMAIL`: Your Redgate email
- `RG_TOKEN`: Your Redgate PAT token (mark as secret)

### 2. Configure Databases
Set up the following databases:
- `MySimpleMigration_dev` - Development database
- `MySimpleMigration_shadow` - Shadow database for Flyway Desktop
- `MySimpleMigration_build` - Build/CI database
- `MySimpleMigration_target` - Deployment target database

### 3. Update Connection Strings
Edit `flyway.toml` to update connection strings for your environment.

### 4. Configure Agent Pool
Update `pool: name: default` in `azure-pipelines.yml` if using a different agent pool.

## Flyway Enterprise Verbs Used

| Verb | Purpose |
|------|---------|
| `flyway auth` | Authenticate with Redgate licensing |
| `flyway info` | Display migration status |
| `flyway clean` | Reset database to empty state |
| `flyway migrate` | Apply pending migrations |
| `flyway undo` | Rollback the most recent migration |
| `flyway check -changes` | Detect schema changes to be applied |
| `flyway check -drift` | Detect unexpected changes in target database |
| `flyway check -code` | Static code analysis for SQL quality issues |
| `flyway check -dryrun` | Generate deployment script without executing |

## Project Structure

```
MySimpleMigration/
├── azure-pipelines.yml    # Azure DevOps pipeline definition
├── flyway.toml            # Flyway configuration
├── flyway.user.toml       # User-specific settings (git-ignored)
├── Filter.scpf            # SQL Compare filter file
├── migrations/            # Versioned migration scripts (V*__.sql, U*__.sql)
└── README.md              # This file
```

## Migration Script Naming

Follow Flyway naming conventions:
- **Versioned**: `V{version}__{description}.sql` (e.g., `V001__Create_Tables.sql`)
- **Undo**: `U{version}__{description}.sql` (Enterprise feature)
- **Repeatable**: `R__{description}.sql` (runs every time if changed)

## Artifacts Published

| Artifact | Contents |
|----------|----------|
| `Migration_Scripts-{id}` | All migration scripts from the migrations folder |
| `Deployment_Report-{id}` | HTML report showing changes and drift |
| `Deployment_Status-{id}` | Deployment completion status |

## Customization

### Adding More Environments
1. Add environment section in `flyway.toml`
2. Duplicate Stage 3 & 4 in pipeline for each environment
3. Update dependencies between stages

### Changing Approval Settings
Edit the `ManualValidation@0` task in the pipeline to:
- Change `notifyUsers` to your team's email
- Modify `onTimeout` behavior
- Add custom instructions

## License

Use at your own risk. No support provided.
