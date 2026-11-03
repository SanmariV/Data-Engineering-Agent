---
applyTo: "models/staging/**"
---

# Staging models (silver)

Each staging model is the single clean entry point for exactly ONE bronze table.

## Rules

- Folder: `models/staging/<source>/`. Name: `stg_<source>__<entity>s` (double underscore, plural).
- Exactly one staging model per bronze table (1:1).
- Read ONLY with `source()`. NEVER `ref()` another model (except `base_` models, see below).
- Allowed: renaming to business terms, casting types, simple maths (cents → currency), `CASE` into buckets or `is_`/`has_` booleans, trimming, null handling, UTC conversion, deduping exact ingestion duplicates.
- Forbidden: joins, aggregations, `group by`, business rules, KPI logic, filtering out valid business rows, window functions that change the grain.
- Materialisation comes from the folder (`view`). Do not override unless the model is too slow; then use `incremental`.
- Access is `private` in group `silver` (set at folder level).
- Keep `_ingested_at` from bronze.

## Base models

When one clean entity needs a union or join (per-region tables, soft-delete tables), create `base_<source>__<entity>s` in `models/staging/<source>/base/`. Then join or union them in the `stg_` model. This is the ONLY place a join is allowed in staging.

## YAML

- Sources go in `_<source>__sources.yml`, with `description`, `loaded_at_field: _ingested_at` and `freshness` (`warn_after`, `error_after`).
- Models go in `_<source>__models.yml`, with a description and `unique` + `not_null` on the primary key.
- Use `accepted_values` on status and code columns.

## Template

```sql
with

source as (

    select * from {{ source('<source>', '<table>') }}

),

renamed as (

    select
        -- ids
        cast(id as string) as <entity>_id,

        -- strings

        -- numerics

        -- booleans

        -- dates

        -- timestamps
        _ingested_at

    from source

)

select * from renamed
```
