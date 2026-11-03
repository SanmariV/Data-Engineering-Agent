# Databricks dbt Copilot Starter Kit

A starter kit for using GitHub Copilot to scaffold and develop dbt projects on
Databricks. It provides engineering standards, automatically applied
instructions, task prompts, and a tool for generating an Information Matrix.
This repository is the kit itself; run the scaffold prompt to create a
project-specific dbt structure.

## What’s included

- [`AGENTS.md`](AGENTS.md) and
  [`databricks_dbt_engineering_standards.md`](databricks_dbt_engineering_standards.md):
  project rules and reference implementations.
- [`.github/instructions/`](.github/instructions/): layer-specific and YAML
  guidance; [`.github/copilot-instructions.md`](.github/copilot-instructions.md)
  provides concise Copilot guidance.
- [`.github/prompts/`](.github/prompts/): prompts to scaffold a project, build
  an Information Matrix, and create an architecture diagram.
- [`scripts/build_information_matrix.py`](scripts/build_information_matrix.py)
  and [`scripts/profiling/`](scripts/profiling/): workbook generation and
  read-only Databricks profiling queries.
- [`seeds/business_glossary.csv`](seeds/business_glossary.csv): glossary seed
  template.
- [`copilot_agent_guide.md`](copilot_agent_guide.md) and
  [`information_matrix_instructions.md`](information_matrix_instructions.md):
  setup and operating guidance.

## Getting started

1. Copy this kit into a new repository and open it in VS Code.
2. Install GitHub Copilot and Copilot Chat. Enable `chat.useAgentsMdFile` and
   `chat.promptFiles`, then use **Agent** mode.
3. Install the project tools:

   ```bash
   pip install "dbt-databricks>=1.12,<2.0" sqlfluff sqlfluff-templater-dbt
   pip install -r scripts/requirements-matrix.txt
   ```

4. Sign in to Databricks using OAuth and a development workspace.
5. Run `/scaffold-databricks-project` in Copilot Chat and provide the project
   name, bronze sources, and gold domains. Review all reported TODOs and
   decisions before merging.

See [`copilot_agent_guide.md`](copilot_agent_guide.md) for detailed setup,
scaffolding, and development steps.

## Information Matrix

After the dbt project is deployed and production artifacts are available,
run `/information-matrix` or use the script’s `profile`, `build`, and `blank`
subcommands. Install its dependencies with
`pip install -r scripts/requirements-matrix.txt`.

Profiling requires the designated **read-only matrix service principal**; never
use a personal token. Workbooks containing sampled data are written under
`target/` and must not be committed. See
[`information_matrix_instructions.md`](information_matrix_instructions.md)
for inputs and commands.

## Project conventions

Use Databricks SQL with `dbt-databricks`; follow the bronze → staging →
intermediate → marts flow. Use `dev` for local work, never target `prod`, and
do not commit credentials, `profiles.yml`, or generated workbooks.
