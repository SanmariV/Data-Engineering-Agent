# AGENTS.md

Instructions for GitHub Copilot (Chat, agent mode, code review and the coding agent) working in this repository.
Full rationale lives in `databricks_dbt_engineering_standards.md`. These rules win over your general habits. If a request conflicts with a rule, say so instead of breaking it silently.

## What this repo is

A dbt project that transforms data on Databricks. dbt compiles SQL; a Databricks SQL warehouse (Spark + Photon) runs it. Production runs as a Lakeflow Jobs dbt task, defined in a Databricks Asset Bundle (`databricks.yml`, `resources/`).

- Adapter: `dbt-databricks>=1.12,<2.0` (needed for `materialized='metric_view'`)
- SQL dialect: Databricks SQL. Never write T-SQL, Snowflake or BigQuery syntax.
- Bronze is loaded by Lakeflow ingestion, not dbt. dbt only reads it through `source()`.

## Layer rules (never break these)

```
bronze (sources) → staging (stg_) → intermediate (int_) → marts (fct_/dim_) → metric views (mv_) / consumers
```

| Layer | Folder | Reads from | Materialisation | Access |
| --- | --- | --- | --- | --- |
| Staging | `models/staging/<source>/` | `source()` only | `view` | `private`, group `silver` |
| Intermediate | `models/intermediate/<domain>/` | `ref()` to `stg_` / `int_` | `view` or `table`; `incremental` if large | `protected`, group `silver` |
| Marts | `models/marts/<domain>/` | `ref()` to `int_` (or another mart) | `table` or `incremental`, never `view` | `public`, contract enforced |
| Metric views | `models/marts/<domain>/` | `ref()` to `fct_` / `dim_` | `metric_view` | `public` |
| AI context | `models/context/<domain>/` | `ref()` to `stg_` / `int_` | `incremental` | `protected` |

- `source()` appears ONLY in `models/staging/`.
- A `fct_` or `dim_` model NEVER calls `ref('stg_...')`. Add or reuse an `int_` model instead.
- An `int_` model NEVER reads a mart.
- NEVER hard-code `catalog.schema.table`. Use `source()` or `ref()`.
- NEVER set `database`, `schema` or `catalog` in a model. Folders set them in `dbt_project.yml`, and the macros in `macros/` route them.
- Staging: rename, cast, simple maths, `CASE` buckets, dedupe exact duplicates. NO joins, NO aggregations, NO business logic.
- One staging model per bronze table (1:1).

## Naming

| Thing | Pattern | Example |
| --- | --- | --- |
| Staging | `stg_<source>__<entity>s` (double underscore) | `stg_salesforce__accounts` |
| Base | `base_<source>__<entity>s` in `staging/<source>/base/` | `base_shopify__orders_eu` |
| Intermediate | `int_<entity>s_<verb>s` | `int_payments_pivoted_to_orders` |
| Fact / dimension | `fct_<process>s` / `dim_<entity>s` | `fct_orders`, `dim_customers` |
| Metric view | `mv_<process>s` | `mv_orders` |
| AI context | `ctx_<entity>s_<step>` | `ctx_call_transcripts_chunked` |
| Sources YAML | `_<source>__sources.yml` | `_salesforce__sources.yml` |
| Models YAML | `_<source>__models.yml`, `_int_<domain>__models.yml`, `_<domain>__models.yml` | `_finance__models.yml` |

Columns: `snake_case`, business terms, no abbreviations (`customer`, not `cust`), no reserved words.

| Kind | Rule |
| --- | --- |
| Primary key | `<entity>_id`, string; never a bare `id` |
| Foreign key | same name as the key it references |
| Surrogate key | `<entity>_key` via `dbt_utils.generate_surrogate_key()` |
| Boolean | `is_` / `has_` prefix |
| Timestamp | `<past_tense_event>_at`, UTC |
| Date | `<past_tense_event>_date` |
| Money | `decimal(18,2)` in currency units |
| Metadata | leading underscore: `_ingested_at` |

Column order: ids, strings, numerics, booleans, dates, timestamps.

## SQL style

- Lowercase keywords; 4-space indents; trailing commas; lines of 80 characters or fewer.
- Import CTEs first (one per `ref`/`source`, named after the model), then one-job functional CTEs, then `select * from <final_cte>`.
- Explicit `as`. `inner join` / `left join` only, never bare `join` or `right join`. No single-letter aliases.
- Prefix columns with the CTE name when joining. `union all` by default. `group by 1, 2` or `group by all`.
- Jinja: `{{ like_this }}` with spaces; use `{# comments #}` for notes that should not be compiled.
- YAML: 2-space indents; explicit lists (`select: ['bi_analysts']`).

Staging template:

```sql
with

source as (

    select * from {{ source('salesforce', 'account') }}

),

renamed as (

    select
        -- ids
        cast(id as string) as account_id,

        -- strings
        trim(name) as account_name,

        -- numerics
        cast(annual_revenue as decimal(18, 2)) as annual_revenue,

        -- booleans
        coalesce(is_deleted, false) as is_deleted,

        -- timestamps
        cast(created_date as timestamp) as created_at,
        _ingested_at

    from source

)

select * from renamed
```

## Incremental models and idempotence

- Always set `unique_key`, `incremental_strategy` and `on_schema_change` (`append_new_columns` or `sync_all_columns`, never `ignore`).
- Strategy: `merge` for updates by key; `replace_where` / `insert_overwrite` for date ranges; `append` only for immutable events; `microbatch` for large time series.
- Incremental filters use a lookback on `_ingested_at` against `{{ this }}`, e.g. `max(_ingested_at) - interval 3 days`.
- NEVER use `current_timestamp()`, `current_date()`, `rand()` or `monotonically_increasing_id()` in filters or keys. Runtime dates come in through `var()`.
- Large tables: `liquid_clustered_by=[...]`, not `partition_by` / ZORDER.

## Do not write stored procedures

Do not generate `CREATE PROCEDURE`, notebooks or DML scripts for silver or gold. Translate instead:

| Procedural pattern | Write this |
| --- | --- |
| `INSERT` / `UPDATE` / `DELETE` | a `SELECT` with `CASE` / `WHERE` |
| `MERGE` | `incremental` + `merge` + `unique_key` |
| SCD2 (`StartDate`/`EndDate`/`IsCurrent`) | a `snapshot` over a staging model |
| Temp tables | CTEs, or an `int_` model if reused |
| Parameters | `var()` |
| Loops / dynamic SQL | Jinja loops and macros |
| `GRANT` | the `grants` config |
| Transactions | split into models (each is one atomic Delta write) |

Hooks may only touch the model's own table.

## Every new or changed model must have

- An entry in the folder's `_*.yml` with a `description` that states the grain, and a description on every column (unit and allowed values where relevant).
- Primary key tests: `unique` + `not_null` (staging, intermediate after a re-grain, marts).
- Marts: `contract: {enforced: true}`, every column with `data_type`, a `not_null` + `primary_key` constraint on the key, and `relationships` tests from fact keys to dimensions.
- Unit tests (`unit_tests:`) for `CASE` trees, window functions, date maths and incremental logic.
- Shared definitions go in `{% docs %}` blocks and are reused with `{{ doc('...') }}`.
- Checks reused across models become a generic test in `tests/generic/`.
- Breaking change to a public mart: new version (`_v2`) plus a `deprecation_date` on the old one.

Mart YAML template:

```yaml
models:
  - name: fct_orders
    description: One row per order. Grain = order_id.
    config:
      materialized: incremental
      contract: {enforced: true}
    columns:
      - name: order_id
        data_type: string
        description: Unique identifier of the order.
        constraints:
          - type: not_null
          - type: primary_key
        data_tests: [unique]
```

## AI context models (`ctx_`)

- Chunk at natural boundaries (turns, paragraphs); keep the source row id on every chunk.
- Every derived row carries its source ids (provenance).
- AI output matches a declared schema: enforced contract plus `accepted_values` on labels.
- Prompts live in the repo (`prompts/` or a macro) with a version name, e.g. `signal_classify_v3`. Record the prompt version and endpoint in the model's `meta`.
- `ai_query` / `ai_classify` only inside `incremental` models, so each row is scored once.
- Add a groundedness test on generated fields.

## Scaffolding a project

New projects and new source systems are scaffolded with `.github/prompts/scaffold-databricks-project.prompt.md`. Copy the reference code from the standards; do not redesign it. Never invent IDs, hosts, keys or column meanings: write `TODO(...)` and report it. Human usage guide: `copilot_agent_guide.md`.

## Information Matrix

The client Information Matrix (`.xlsx`) is generated from this project by `scripts/build_information_matrix.py`. Follow `.github/prompts/information-matrix.prompt.md`.

- NEVER edit the workbook by hand, and never commit it (it holds sampled data). It is written to `target/`.
- Facts only people know go in `config.meta.matrix` on the model or column. Keys are listed in `.github/instructions/marts.instructions.md`. If you don't know a value, leave it out; the gap report lists it. Never guess.
- Mark PII columns `config.meta.pii: true`. They are never sampled. Their `matrix.example` must be synthetic.
- Every `mv_` measure needs a `comment`. Every fact description states `Grain = ...`.
- Glossary terms go in `seeds/business_glossary.csv`.
- The profile step runs only as the read-only matrix service principal, never with a personal token.

## Commands

```bash
dbt deps
dbt parse
dbt build --select <model>+            # build and test a model and its children
dbt build --select state:modified+ --defer --state prod_state
sqlfluff lint models/
python ci/check_layers.py              # layer rules, run after dbt parse
python scripts/build_information_matrix.py build --help   # Information Matrix
```

Use the `dev` target locally. Never run against `prod`, and never commit tokens or `profiles.yml` secrets.

## Before you finish a change

- [ ] Correct folder and name prefix
- [ ] `source()` only in staging; no hard-coded tables; no mart → staging `ref`
- [ ] YAML descriptions, primary key tests, contracts on marts
- [ ] Unit tests for complex logic
- [ ] Incremental config complete; no non-deterministic functions in filters or keys
- [ ] `sqlfluff lint` and `python ci/check_layers.py` pass
- [ ] One logical change per pull request

## When reviewing pull requests

Flag, in this order: layer violations, missing tests or contracts, naming violations, non-idempotent logic, style. Cite the rule from this file.
