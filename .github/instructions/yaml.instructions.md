---
applyTo: "models/**/*.yml,dbt_project.yml,packages.yml"
---

# dbt YAML files

- 2-space indents; indented list items; lines of 80 characters or fewer.
- Explicit lists even for one item: `select: ['bi_analysts']`.
- File names: `_<source>__sources.yml`, `_<source>__models.yml`, `_int_<domain>__models.yml`, `_<domain>__models.yml`, `_groups.yml`.
- Every model and every column has a `description`. A model description states the grain ("One row per order. Grain = order_id."). A column description gives the business meaning, unit and allowed values. "The order id" is not enough.
- A definition used in more than one place lives in a `{% docs name %}` block (`models/docs/*.md`) and is referenced with `'{{ doc("name") }}'`.
- Use `data_tests:` (not `tests:`). Use `arguments:` under generic tests that take parameters.
- Do not set `database` or `schema` per model; `dbt_project.yml` sets them by folder.
- In `dbt_project.yml`, keep these folder defaults and do not remove them:

```yaml
models:
  my_project:
    +persist_docs:
      relation: true
      columns: true
    staging:
      +database: silver
      +schema: staging
      +materialized: view
      +group: silver
      +access: private
    intermediate:
      +database: silver
      +schema: intermediate
      +group: silver
      +access: protected
    marts:
      +database: gold
      +materialized: table
      +access: public
      +contract:
        enforced: true
```

- Marts set `+schema: <domain>` per domain subfolder.
- Tags for Unity Catalog go in `databricks_tags`, e.g. `{certified: 'true', domain: 'finance', pii: 'false'}`.
- Information Matrix facts that only people know (business question, SCD type, units, synthetic examples) go in `config.meta.matrix`. Mark PII columns with `config.meta.pii: true`. The key list is in `marts.instructions.md`. Never invent these values.
- The business glossary lives in `seeds/business_glossary.csv` (`category, concept, acronym, context, description`).
