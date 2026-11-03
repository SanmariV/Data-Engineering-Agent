---
agent: agent
description: Scaffold a new dbt-on-Databricks project to the engineering standards, with staging models for the given bronze source systems.
---

# Scaffold a Databricks dbt project

Create the dbt project **${input:project:project name, snake_case, e.g. paradise_games}**.

- Bronze source systems (schemas in `prod_bronze`): **${input:sources:comma separated, e.g. pggames, crm}**
- Gold domains (one folder and schema each): **${input:domains:comma separated, e.g. betting, finance}**
- Requirements Information Matrix (optional): `${input:matrix:path to an .xlsx, or none}`

Follow `AGENTS.md`, `.github/instructions/` and `databricks_dbt_engineering_standards.md`. Where the standards give code, copy it exactly and change only the project name. Do not redesign it.

## Rules for this task

- NEVER invent environment values: workspace hosts, warehouse IDs, service principal IDs, group names, the repo URL. Write `TODO(<what>)` and list each one in your final report.
- NEVER guess a primary key. If a bronze table has no obvious key, ask, or leave the key tests out and list the table under "Needs a decision".
- Read-only against Databricks. Use the `dev` target with your own OAuth login (`auth_type: oauth`). Never use a token. Never target `prod`.
- Don't write marts SQL. Business logic needs a person. This task creates the structure, the staging layer and (optionally) the mart specifications.

## 1. Project skeleton

Create these files. The source of each is in the standards:

| File | Source |
| --- | --- |
| `dbt_project.yml` | Folder defaults from `.github/instructions/yaml.instructions.md`, `persist_docs` from section 15.1, grants from 3.3. Name = the project. One `marts/<domain>` block per domain with `+schema: <domain>`. |
| `packages.yml` | `dbt_utils`, `dbt_expectations`, `dbt_project_evaluator`, `codegen`, `audit_helper` (latest compatible versions) |
| `profiles.example.yml` | `dev` target only: `type: databricks`, `catalog: dev_silver`, `schema: dbt_<user>`, `auth_type: oauth`, host and `http_path` as `TODO`. Never a real `profiles.yml`. |
| `macros/generate_database_name.sql`, `macros/generate_schema_name.sql`, `macros/_macros.yml` | Section 3.2 |
| `models/_groups.yml` | Section 7.4 |
| `ci/check_layers.py` | Section 7.4 |
| `ops/publish_dbt_state.py` | Section 12.2 |
| `databricks.yml`, `resources/dbt_prod_job.yml` | Section 12.3, with `TODO` variables |
| `.github/workflows/dbt_ci.yml` | The five CI steps in section 12.2. Credentials come from repository secrets for the CI service principal. |
| `.sqlfluff`, `.sqlfluffignore` | Section 9.5 |
| `.gitignore` | `target/`, `dbt_packages/`, `logs/`, `prod_state/`, `profiles.yml`, `*.xlsx` except `docs/information_matrix_template.xlsx` |
| `seeds/business_glossary.csv` | Header row only: `category,concept,acronym,context,description` |
| Empty folders with a `.gitkeep` | `models/intermediate/<domain>/`, `models/marts/<domain>/`, `snapshots/`, `tests/generic/`, `tests/singular/`, `analyses/` |

## 2. Sources (one per bronze schema)

For each source system:

1. Install packages and generate the source YAML from the real bronze tables:

   ```bash
   dbt deps
   dbt run-operation generate_source --args '{"schema_name": "<source>", "database_name": "prod_bronze", "generate_columns": true, "include_data_types": true}'
   ```

2. Save the output as `models/staging/<source>/_<source>__sources.yml`. Add a `description` for the source, plus `loaded_at_field: _ingested_at` and `freshness` (section 4.2). If a table has no `_ingested_at`, say so; don't make one up.

## 3. Staging models (one per bronze table)

For each table in the source YAML:

1. Get the column list: `dbt run-operation generate_base_model --args '{"source_name": "<source>", "table_name": "<table>"}'`.
2. Write `models/staging/<source>/stg_<source>__<entity>s.sql` using the staging template in `.github/instructions/staging.instructions.md`. Rename every column to the naming rules: `<entity>_id` keys cast to string, `is_`/`has_` booleans, `_at` timestamps, `_date` dates, `decimal(18, 2)` money, no abbreviations. Group the columns as ids, strings, numerics, booleans, dates, timestamps. Keep `_ingested_at`.
3. Add the model to `_<source>__models.yml`: a description stating the grain, a description on every column, and `unique` + `not_null` on the primary key. Use `accepted_values` only where the allowed values are known (ask, or leave it out).
4. Where you can't tell what a column means, write `description: TODO(meaning of <bronze column>)` and list it. Don't invent a meaning from the column name alone.

## 4. Mart specifications from the Information Matrix (only if a matrix path was given)

Read the matrix **read-only** with a short openpyxl script (never save it). From EntitiesDimensions, Measure Groups, Attributes, Measures and BUS Matrix-current:

- For each entity, plan `dim_<entity>s`; for each measure group, plan `fct_<process>s`. Use the dbt naming rules and put the matrix name in `meta.matrix.name` (e.g. `DimCustomer`).
- Write the plans to `docs/specs/_<domain>__models.yml`, not to `models/`, until the SQL exists:
  - model description and grain;
  - columns with `data_type`, plus descriptions from the Attributes definitions;
  - `meta.matrix` keys (business question, SCD type, presentation, priority) copied from the matrix;
  - `relationships` tests for each 1:M cell in the BUS Matrix;
  - one planned `mv_<process>s` per fact, with each measure's name, `expr` from the "Value calculation rule" where one is given, and `meta.matrix.measures`.
- Copy values exactly as they appear in the matrix. Leave blank cells blank.
- Map bronze columns to staging columns where the Attributes sheet gives a Source Table/Column. Record that mapping as a comment in the spec. It shows which `int_` models will be needed.

## 5. Verify

Run all of these, and fix any failure before you report:

```bash
dbt deps
dbt parse
sqlfluff lint models/
python ci/check_layers.py
dbt build --select staging --target dev
```

## 6. Report back

- the files created, grouped by step;
- a **TODO list**: every `TODO(...)` you left, with the file and line;
- **Needs a decision**: tables without a clear primary key, columns with unknown meaning, sources without `_ingested_at`;
- the results of each command in step 5;
- the next step: build the `int_` and mart models for one domain, then run `/information-matrix`.
