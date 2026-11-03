# Copilot instructions

This is a dbt project on Databricks. dbt compiles SQL; a Databricks SQL warehouse (Spark + Photon) runs it. Production runs as a Lakeflow Jobs dbt task. Write Databricks SQL only, never T-SQL, Snowflake or BigQuery syntax. The adapter is `dbt-databricks>=1.12,<2.0`.

Full rules: `AGENTS.md` (root) and `databricks_dbt_engineering_standards.md`. Folder-specific rules are in `.github/instructions/`.

## Layer flow

bronze (`source()`) → `stg_` → `int_` → `fct_` / `dim_` → `mv_` (metric views) / consumers

- `source()` only in `models/staging/`.
- Marts (`fct_`, `dim_`) never `ref()` a `stg_` model. Use an `int_` model.
- `int_` models never read marts.
- Never hard-code `catalog.schema.table`. Never set `database`/`schema` in a model; folders set them.
- No stored procedures, notebooks or DML scripts for transformations. Write dbt models (MERGE → incremental, SCD2 → snapshot, parameters → `var()`).

## Naming

`stg_<source>__<entity>s` · `int_<entity>s_<verb>s` · `fct_<process>s` · `dim_<entity>s` · `mv_<process>s` · `ctx_<entity>s_<step>`.
Columns: `snake_case`, no abbreviations; keys `<entity>_id` (string); booleans `is_`/`has_`; timestamps `<event>_at` (UTC); dates `<event>_date`; money `decimal(18,2)`.

## Every model

- Described in its folder's `_*.yml`, with grain stated and every column described.
- Primary key tested with `unique` + `not_null`.
- No `current_timestamp()`, `current_date()`, `rand()` or `monotonically_increasing_id()` in filters or keys.
- Marts: PII columns carry `config.meta.pii: true`, and Information Matrix facts go in `config.meta.matrix` (see `marts.instructions.md`). Never invent those values.

## Information Matrix

The Information Matrix workbook is generated, never hand-edited: run the `/information-matrix` prompt (`.github/prompts/information-matrix.prompt.md`), which uses `scripts/build_information_matrix.py`.

## Style

Lowercase SQL, 4-space indents, trailing commas, ≤ 80 characters a line, import CTEs first, `select * from <final_cte>` last, explicit `as`, `inner join`/`left join` only, no single-letter aliases, `union all`. YAML: 2-space indents.

## Code review

When reviewing a pull request, flag issues in this order and cite the rule:

1. Layer violations (`source()` outside staging, mart → staging `ref`, hard-coded tables)
2. Missing tests, descriptions or contracts (marts need `contract: {enforced: true}`)
3. Naming violations
4. Non-idempotent logic or incomplete incremental config
5. Style

Do not comment on formatting that SQLFluff already enforces unless it hides a bug.
