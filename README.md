# MySimpleMigration

A simplified Flyway **Migrations-based Pipeline** for Azure DevOps.

> **Version 1.0** - First working version  
> Use at your own risk, no support provided. Please use in a sandbox environment.

## Overview

This project demonstrates a streamlined Flyway migrations workflow with a **3-stage pipeline**:
- **Build** - Validate migrations compile successfully
- **Check** - Generate deployment report and dry-run script
- **Deploy** - Apply migrations to target (with approval gate)

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure DevOps Pipeline                        │
├─────────────────┬─────────────────┬─────────────────────────────────┤
│   Stage 1       │   Stage 2       │   Stage 3                       │
│   BUILD         │   CHECK         │   DEPLOY                        │
├─────────────────┼─────────────────┼─────────────────────────────────┤
│ • Flyway Auth   │ • Check Changes │ • Manual Approval Gate          │
│ • Clean Build   │ • Check Drift   │ • Conditional Migrate           │
│ • Migrate       │ • Check DryRun  │                                 │
│ • Info          │ • Publish Report│                                 │
│                 │ • Publish Script│                                 │
├─────────────────┼─────────────────┼─────────────────────────────────┤
│ Database:       │ Database:       │ Database:                       │
│ Build           │ Check + Target  │ Target                          │
└─────────────────┴─────────────────┴─────────────────────────────────┘
```

## Databases

| Database | Purpose | Managed By |
|----------|---------|------------|
| `MySimpleMigration_dev` | Local development | Create script |
| `MySimpleMigration_target` | Deployment target | Create script |
| `MySimpleMigration_build` | CI validation | Flyway (provisioner=clean) |
| `MySimpleMigration_check` | Report generation | Flyway (provisioner=clean) |
| `MySimpleMigration_shadow` | Schema comparison | Flyway (provisioner=clean) |

## Quick Start

### 1. Create Databases
Run `scripts/CreateMySimpleMigrationDatabases.sql` in SQL Server Management Studio.

> **Note:** The create script is written for **MS SQL Server**. However, the pipeline itself will work with any database that Flyway has advanced support for (PostgreSQL, Oracle, MySQL, etc.) - just update the `flyway.toml` connection strings and create equivalent databases for your DBMS.

This script is **idempotent** - it can be run multiple times safely:
- Drops and recreates `_dev` and `_target` (fresh start)
- Creates `_check`, `_build`, `_shadow` if they don't exist (empty)
- Populates `_dev` and `_target` with identical schema and sample data

### 2. Configure Azure DevOps
Create a variable group named `RG_Auth` with:
| Variable | Description |
|----------|-------------|
| `RG_EMAIL` | Your Redgate email |
| `RG_TOKEN` | Your Redgate PAT token (mark as secret) |

### 3. Set Up Agent Pool
Update `pool: name: default` in `azure-pipelines.yml` if using a different agent pool.

### 4. Baseline the Project
Use Flyway Desktop to baseline the project from the development database.

## Project Structure

```
MySimpleMigration/
├── azure-pipelines.yml                    # 3-stage pipeline (~120 lines)
├── flyway.toml                            # Flyway configuration
├── flyway.user.toml                       # User-specific settings (git-ignored)
├── Filter.scpf                            # SQL Compare filter file
├── migrations/                            # Versioned migration scripts
├── schema-model/                          # Schema model (Flyway Desktop)
├── scripts/
│   ├── CreateMySimpleMigrationDatabases.sql   # Idempotent DB creation
│   └── CleanupOldDatabases.sql                # Cleanup utility
└── README.md
```

## Pipeline Features

### Parameters
Toggle stages on/off when running the pipeline:
- `enableBuild` (default: true)
- `enableCheck` (default: true)
- `enableDeploy` (default: true)

### Deployment ID
Uses PR number or build number for artifact naming:
- `CheckReport-{id}.html`
- `deploy-{id}.sql`

### Artifacts Published
| Artifact | Contents |
|----------|----------|
| `CheckReport-{deploymentId}` | HTML report with changes, drift, dry-run analysis |
| `DeployScript-{deploymentId}` | SQL script showing exact statements to execute |

### Failure Behavior
- If **Build fails** → Check and Deploy are skipped
- If **Check fails** → Deploy is skipped
- Pipeline stops on any step failure (except dry-run script generation)

## Flyway Commands Used

| Command | Stage | Purpose |
|---------|-------|---------|
| `flyway auth` | Build | Authenticate with Redgate licensing |
| `flyway clean` | Build | Reset build database to empty state |
| `flyway migrate` | Build, Deploy | Apply pending migrations |
| `flyway info` | Build, Deploy | Display migration status |
| `flyway check -changes` | Check | Detect schema changes to be applied |
| `flyway check -drift` | Check | Detect unexpected changes in target |
| `flyway check -dryrun` | Check | Generate deployment script preview |

## Migration Script Naming

Follow Flyway naming conventions:
- **Versioned**: `V{version}__{description}.sql` (e.g., `V001__Create_Tables.sql`)
- **Undo**: `U{version}__{description}.sql` (Enterprise feature)
- **Repeatable**: `R__{description}.sql` (runs every time if changed)
- **Baseline**: `B{version}__{description}.sql` (baseline marker)

## Sample Database Schema

The included database script creates the full AutoPilot FastTrack schema:

**4 Schemas:** Customers, Logistics, Operation, Sales

**Tables include:**
- Sales.Customers, Sales.Orders, Sales.Order Details, Sales.Territories
- Operation.Employees, Operation.Products, Operation.Categories
- Logistics.Flight, Logistics.Suppliers, Logistics.Shippers, Logistics.Region

**Plus:** Views, Stored Procedures, and sample data

## Customization

### Adding More Environments
1. Add environment section in `flyway.toml`
2. Duplicate Check and Deploy stages for each environment
3. Update stage dependencies

### Changing Approval Settings
Edit the `ManualValidation@0` task to:
- Change notification recipients
- Modify timeout behavior
- Add custom instructions

## Based On

- [Flyway AutoPilot FastTrack](https://github.com/red-gate/Flyway-AutoPilot-FastTrack) by Redgate
- Simplified from 6 stages to 3 stages
- Single deployment target instead of Test/Prod

## License

Use at your own risk. No support provided.
