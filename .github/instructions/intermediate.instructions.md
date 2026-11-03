---
applyTo: "models/intermediate/**"
---

# Intermediate models (silver)

All business logic, joins, re-graining and heavy aggregation happen here. Intermediate models are never exposed to consumers.

## Rules

- Folder: `models/intermediate/<domain>/` (by business domain, e.g. `finance/`, not by source).
- Name: `int_<entity>s_<verb>s`, where the verb says what it does: `int_order_items_joined`, `int_payments_pivoted_to_orders`, `int_opportunities_aggregated_to_account`.
- Keep a double underscore only for source-specific models that are unioned later: `int_shopify__orders_summed`.
- Read ONLY with `ref()` to `stg_` or other `int_` models. NEVER `source()`. NEVER `ref()` a `fct_`, `dim_` or `mv_` model.
- Access is `protected` in group `silver`.
- Combine roughly 4 to 6 inputs at most. If a model needs more, split it.
- One intermediate model feeding many marts is a smell. Say so if you see it.
- Use `dbt_utils.generate_surrogate_key()` for multi-column keys; never `monotonically_increasing_id()`.

## Materialisation

| Situation | Use |
| --- | --- |
| Light logic | `view` (default) |
| Heavy joins/aggregations, or read by 2+ marts | `table` |
| Large fact-grain data, full rebuild too slow | `incremental` |
| Tiny helper used once | `ephemeral` (avoid for heavy logic) |

## Incremental config

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='<entity>_id',
    on_schema_change='append_new_columns',
    liquid_clustered_by=['<most_filtered_column>']
) }}

...
{% if is_incremental() %}
where _ingested_at > (select max(_ingested_at) - interval 3 days from {{ this }})
{% endif %}
```

## Tests

- `unique` + `not_null` on the grain key after any re-grain.
- `unit_tests:` for `CASE` trees, window functions, date maths, revenue rules and incremental logic.
- Describe the model in `_int_<domain>__models.yml`, stating the grain.
