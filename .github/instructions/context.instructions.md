---
applyTo: "models/context/**,prompts/**"
---

# AI context models (`ctx_`)

AI-derived context (chunked, classified, embedded or summarised text) is built as tested dbt models, never as notebooks or prompts that exist only in a UI.

## Rules

- Folder: `models/context/<domain>/`. Name: `ctx_<entity>s_<step>`, e.g. `ctx_call_transcripts_chunked`, `ctx_call_signals_classified`.
- Read ONLY with `ref()` to `stg_` or `int_` models.
- Chunking: split at natural boundaries (turns, paragraphs, sections), never at a fixed character count.
- Provenance: every row keeps the source row ids it came from, all the way through the DAG.
- Structured output: enforced contract, plus `accepted_values` on every label column.
- Prompts live in `prompts/` or a macro, with a version in the name (`signal_classify_v3`). Never inline an unversioned prompt string in a model.
- Record the prompt version and serving endpoint in `meta`:

```yaml
config:
  meta:
    prompt_version: signal_classify_v3
    model_endpoint: databricks-meta-llama-3-3-70b-instruct
```

- `ai_query()` / `ai_classify()` only inside `incremental` models, with a `unique_key`, so each row is scored once. Never in a `view` or full-refresh `table`.
- Classify before ranking when text is short or formulaic.
- Retrieval: Mosaic AI Vector Search index synced from a gold Delta table.
- Tests: groundedness on generated fields (the cited evidence exists in the source text), schema conformance, and a golden-set test where one exists.
- State in the model description what a reliable answer must contain.
