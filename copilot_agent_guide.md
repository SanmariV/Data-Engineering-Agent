# Using the Copilot agent for Databricks dbt projects

This folder is a starter kit. Copy it into a new repository and GitHub Copilot will build and document a Databricks dbt project to the engineering standards. The two main jobs are:

1. **Scaffold a project**: `/scaffold-databricks-project` creates the dbt project, the CI/CD and job definitions, and one staging model per bronze table. Given a requirements Information Matrix, it also writes the mart specifications.
2. **Produce the Information Matrix**: `/information-matrix` builds the client workbook from the project, then lists what a person still has to fill in.

Between those two jobs, Copilot follows the same rules on every change, because it reads `AGENTS.md` and the instruction files automatically.

## 1. What is in the kit

| File | What Copilot uses it for |
| --- | --- |
| `AGENTS.md` | Main rules for agent mode and the Copilot coding agent |
| `.github/copilot-instructions.md` | Short rules for Copilot Chat and pull request review |
| `.github/instructions/*.instructions.md` | Layer rules, applied by folder (`staging`, `intermediate`, `marts`, `context`, YAML) |
| `.github/prompts/scaffold-databricks-project.prompt.md` | The scaffolding job |
| `.github/prompts/information-matrix.prompt.md` | The Information Matrix job |
| `databricks_dbt_engineering_standards.md` | Full standards, plus the reference code the scaffold copies |
| `scripts/build_information_matrix.py`, `scripts/profiling/` | Information Matrix generator and its read-only SQL |
| `information_matrix_instructions.md` | How to run the matrix by hand, and the v1.1 migration notes |

## 2. One-time setup in VS Code

1. Install the GitHub Copilot and GitHub Copilot Chat extensions and sign in.
2. In Settings, turn on `chat.useAgentsMdFile` (so `AGENTS.md` is read) and `chat.promptFiles` (so `/` prompts appear).
3. Install dbt and the tools: `pip install "dbt-databricks>=1.12,<2.0" sqlfluff sqlfluff-templater-dbt` and `pip install -r scripts/requirements-matrix.txt`.
4. Install the Databricks CLI and log in with your own account: `databricks auth login --host <workspace URL>`.
5. Open Copilot Chat and switch the mode to **Agent**. Prompt files run only in agent mode.

## 3. Starting a new project

**Before you start, have these ready.** The agent leaves a `TODO` for anything missing instead of guessing:

| Needed | Example | Used for |
| --- | --- | --- |
| Project name | `paradise_games` | `dbt_project.yml`, job and volume paths |
| Bronze source schemas | `pggames`, `crm` in `prod_bronze` | One source and staging folder each |
| Gold domains | `betting`, `finance` | Mart folders and gold schemas |
| Catalogs created by platform admins | `dev_silver`, `test_gold`, `prod_gold`, `prod_ops` | Section 3 of the standards |
| Workspace host and SQL warehouse IDs (dev, CI, prod) | `adb-123.azuredatabricks.net` | `profiles.example.yml`, `databricks.yml` |
| Prod and CI service principals | application IDs | Job `run_as`, CI secrets |
| Repository URL | `https://github.com/org/repo` | Asset Bundle `git_source` |
| Primary key of each bronze table | `customers.id` | Staging key tests |
| Requirements Information Matrix (optional) | `Information Matrix v1.1.xlsx` | Mart specifications |

**Steps:**

1. Create an empty repository and copy this kit into it.
2. Make sure you can read `prod_bronze` with your own login (`dbt run-operation` reads the bronze tables through the `dev` target).
3. In Copilot Chat (agent mode), type `/scaffold-databricks-project`. Fill in the project name, sources, domains and, optionally, the matrix path.
4. The agent creates the skeleton and generates sources with `dbt-codegen`. It writes one staging model per table and runs `dbt parse`, `sqlfluff lint`, `check_layers.py` and `dbt build --select staging --target dev`.
5. Read its report. Resolve each `TODO` and each item under **Needs a decision** (primary keys, column meanings, missing `_ingested_at`).
6. Open a pull request. CI runs Slim CI against the test catalogs, and Copilot code review checks the change against the rules.
7. After the first merge, deploy the job with `databricks bundle deploy -t prod`. The first successful run publishes `manifest.json` and `catalog.json` to the state volume.

**Adding a source system later:** run `/scaffold-databricks-project` again with only the new source and the existing project name. Say "steps 2, 3 and 5 only" in the chat so the skeleton is not rewritten.

## 4. Building the business logic

The scaffold stops at staging, because joins and business rules need a person to decide them. Build each domain with ordinary agent-mode requests. The folder instructions apply automatically. For example:

- "Create `int_bets_joined_to_customers` joining `stg_pggames__bets` to `stg_pggames__customers`."
- "Turn `docs/specs/_betting__models.yml` into `fct_bets` and `dim_customers`, reading only from `int_` models."
- "Translate this stored procedure into dbt models" (paste it). The agent follows section 14 of the standards.

Ask for one logical change per pull request. If a request would break a rule (for example, a mart reading a staging model), the agent should say so rather than do it.

## 5. Producing the Information Matrix

Once marts are built in production:

1. Copy `manifest.json` and `catalog.json` from `/Volumes/prod_ops/dbt/state/<project>/latest/` into `prod_state/`.
2. Set the matrix service principal's environment variables (`DATABRICKS_HOST`, `DATABRICKS_HTTP_PATH`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET`).
3. Type `/information-matrix`, and give the version, the author and the previous matrix.
4. The agent profiles the data (read-only), builds the workbook into `target/`, and fixes the gaps it can from the repo. It then lists the decisions only a person can make.
5. Fill those `meta.matrix` values in the YAML, run it again, review the workbook, and save it to the client document location.

The first time you move from a hand-made matrix such as v1.1, read section 2 of `information_matrix_instructions.md`.

## 6. Using the Copilot coding agent on GitHub instead

You can also assign a GitHub issue to Copilot, for example "Add staging models for the `crm` source, following `.github/prompts/scaffold-databricks-project.prompt.md` steps 2, 3 and 5". The coding agent reads `AGENTS.md` and `.github/copilot-instructions.md`, works on a branch, and opens a pull request.

It runs in GitHub Actions, not on your machine, so by default it has **no Databricks access**. It can't run `dbt run-operation`, `dbt build` or the matrix profile. Either:

- run the Databricks-dependent steps yourself in VS Code and let the coding agent do the rest; or
- add `.github/workflows/copilot-setup-steps.yml` to install dbt, and store a **read-only dev** service principal in the repository's `copilot` environment secrets. Never give it prod credentials.

## 7. What to check in every agent change

- [ ] No values were invented: IDs, keys, column meanings and business facts are either sourced or marked `TODO`
- [ ] `dbt parse`, `sqlfluff lint` and `python ci/check_layers.py` pass
- [ ] No `profiles.yml`, tokens or `.xlsx` with data were committed
- [ ] Nothing ran against `prod`
- [ ] The pull request covers one logical change
