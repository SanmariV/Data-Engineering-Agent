---
applyTo: "models/marts/**"
---

# Marts and metric views (gold)

Marts are the only models consumers see. Each is one entity at one fixed grain, with an enforced contract.

## Rules

- Folder: `models/marts/<domain>/`. Each domain becomes its own gold schema.
- Names: `fct_<business_process>s` (facts), `dim_<entity>s` (dimensions), `mv_<business_process>s` (metric views).
- No team or time roll-up in names: not `finance_orders`, not `orders_per_day`. Roll-ups belong in metric views.
- Read ONLY with `ref()` to `int_` models or other marts. NEVER `ref('stg_...')`. NEVER `source()`. If a mart needs staging data, create or extend an `int_` model.
- Combine at most 4 to 5 concepts; beyond that, add an intermediate model.
- One concept, one mart. Do not create a second version of an entity for another team.
- Wide and denormalised, unless the mart feeds a metric view (then keep facts and dimensions normalised).
- Materialisation: `table` or `incremental`. NEVER `view`.
- Access `public`, `contract: {enforced: true}`.

## Mart YAML (`_<domain>__models.yml`)

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
      - name: customer_id
        data_type: string
        description: The customer who placed the order.
        data_tests:
          - relationships:
              arguments:
                to: ref('dim_customers')
                field: customer_id
```

- Every column listed with `data_type` and a description (unit, allowed values).
- Every fact foreign key has a `relationships` test to its dimension.
- Breaking change: create `fct_<name>_v2` and set a `deprecation_date` on the old version.
- Consumer access via `grants` config, never `GRANT` statements.

## Metric views

Metric views are dbt models with `materialized='metric_view'`. The body is YAML, not SQL. They read only from `fct_` / `dim_` models.

```sql
{{ config(materialized='metric_view') }}

version: 1.1
source: "{{ ref('fct_orders') }}"
joins:
  - name: customers
    source: "{{ ref('dim_customers') }}"
    on: source.customer_id = customers.customer_id
dimensions:
  - name: ordered_month
    expr: date_trunc('month', ordered_at)
measures:
  - name: revenue
    expr: sum(order_total)
    synonyms: [sales, turnover]
```

Add `synonyms` and `display_name` to measures and dimensions so Genie maps questions correctly.

## Information Matrix metadata (`meta.matrix`)

The Information Matrix workbook is generated from these YAML files by `scripts/build_information_matrix.py`. Facts that only people know live in `meta.matrix`, next to the model, so the script copies them instead of anyone guessing. Never invent these values: if you don't know one, leave it out and the gap report will list it.

```yaml
models:
  - name: dim_customers
    description: One row per customer. Grain = customer_id.
    config:
      meta:
        matrix:
          name: DimCustomer              # name used in the matrix
          business_question: Who         # Who, What, Where, When, Why
          scd_type: 2                    # 0, 1, 2 or 3
          presentation: ['data_lake', 'power_bi']
          priority: High                 # High, Medium, Low
    columns:
      - name: customer_name
        description: Customer full name.
        config:
          meta:
            pii: true                    # never sampled
            matrix:
              example: 'Thabo M***'      # synthetic, required when pii
      - name: province
        config:
          meta:
            matrix:
              hierarchy: {name: Geography, level: 1}

  - name: fct_bets
    description: One row per bet. Grain = bet_id.
    config:
      meta:
        matrix:
          name: FactBettingDetail
          genie_description: Every settled and unsettled bet.
          event_frequency: About 1 million bets a day
          refresh_frequency: Daily by 06:00
          group_type: Physical           # Physical, Logical, Mixed

  - name: mv_bets
    config:
      meta:
        matrix:
          measures:
            sales:                       # measure name in the mv_ YAML
              additivity: Additive       # Additive, Semi-Additive, Non-Additive
              unit: Rands                # Rands, Units, Cost, Margin, %, Days
              priority: High
              scenarios: ['actual']      # actual, budget, forecast, benchmark
```

- Model keys: `name`, `business_question`, `scd_type` (dims); `genie_description`, `grain`, `event_frequency`, `refresh_frequency`, `group_type` (facts); `presentation`, `priority`, `ready`, `planned_release`, `comments` (both).
- Column keys: `pii` (directly under `meta`), and under `matrix`: `example`, `scd`, `role`, `hierarchy`, `scope_rule`, `value_rule`, `comments`.
- Any other matrix column: `matrix.extra: {"<exact column header>": "<value>"}`.
- Role-playing foreign keys (two or more keys to the same dimension, e.g. `placed_date`, `settled_date` to `dim_dates`) can set `matrix.role: PlacedDate`.
- Every metric view measure needs a `comment`; it becomes the measure definition.
