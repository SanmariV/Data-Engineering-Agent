# Information Matrix: instructions

How to produce the Information Matrix workbook from the dbt project, and what to watch for. The design is in section 16 of `databricks_dbt_engineering_standards.md`; the step-by-step agent prompt is `.github/prompts/information-matrix.prompt.md` (run it in Copilot Chat as `/information-matrix`).

## 1. One-off setup

1. Install the script's packages:

   ```bash
   pip install -r scripts/requirements-matrix.txt
   ```

2. Make a blank template from the last filled matrix:

   ```bash
   python scripts/build_information_matrix.py blank \
     --source "<filled matrix>.xlsx" \
     --out docs/information_matrix_template.xlsx
   ```

   The blank keeps the Usage Guide, Doc Controls layout, column headers, styles and table formatting. It clears every data row and the version history. It still contains the client's SharePoint location on Doc Controls, so check with the client before committing it to a shared repo.

3. Ask the platform team for the read-only **matrix service principal** (`SELECT` on gold, silver and `system.access`, nothing else). Never use a personal access token.

4. Make sure the production job runs `dbt docs generate --target prod` and publishes `catalog.json` to the state volume (section 12.2 and 12.3 of the standards).

## 2. Moving from v1.1 to the first generated version

Rows are matched across versions **by name**. A row that keeps its name keeps everything people typed into it (comments, transformation logic, priorities). A row whose name changes shows twice: the old one as "Removed", the new one as "Added".

v1.1 uses legacy names, such as `DimCustomer` for entities and `iCustomerID` for columns.

| What is matched | Key | How to keep v1.1 content |
| --- | --- | --- |
| Entities, measure groups | Entity / measure group name | Set `meta.matrix.name` on the model to the v1.1 name, e.g. `name: DimCustomer` on `dim_customers`. |
| Attributes | Entity name + attribute (column) name | Column names cannot be aliased. Where dbt renamed a column (`iCustomerID` → `customer_id`), the v1.1 row shows as Removed and the new one as Added. Copy any v1.1 comments you want to keep into `meta.matrix.comments` (or `meta.matrix.extra`) on the column. |
| Measures | Measure group + measure name | Name the metric view measure as in v1.1, or copy the v1.1 notes into `meta.matrix.measures.<name>`. |
| Glossary | Concept | Use the v1.1 concept names in `seeds/business_glossary.csv`. |

Before publishing the first generated version, review every "Removed" row. Each one is either a real removal or a rename you need to handle as above.

## 3. Each new version

1. Copy `manifest.json` and `catalog.json` from `/Volumes/prod_ops/dbt/state/<project>/latest/` into `prod_state/`.
2. Run `/information-matrix` in Copilot, or run the two steps yourself:

   ```bash
   python scripts/build_information_matrix.py profile \
     --manifest prod_state/manifest.json --out target/matrix_profile.json

   python scripts/build_information_matrix.py build \
     --manifest prod_state/manifest.json --catalog prod_state/catalog.json \
     --profile target/matrix_profile.json \
     --template docs/information_matrix_template.xlsx \
     --previous "<last published matrix>.xlsx" \
     --version "1.2 Production" --author "<your name>" \
     --out "target/Information Matrix 1.2 Production.xlsx"
   ```

3. Read `target/Information Matrix <version>.gaps.md`. Fix gaps in the dbt YAML (`meta.matrix`, descriptions, measure comments), never in the workbook. Then build again.
4. Review the workbook and save it to the client document location. Never commit it to git: it contains sampled data values.

## 4. What is not generated

- **The legacy `BUS Matrix` sheet** (facts down, dimensions across). `BUS Matrix-current` replaces it. In a template made from v1.1, the legacy sheet keeps its old contents; delete it or mark it as superseded.
- **The working sheets**, such as `Measure examples WIP` and `Customer Class Draft`. They are left exactly as they are in the template.
- **Excel dropdowns that point at other sheets.** openpyxl drops these extended data validations when it saves. Dropdowns with an in-sheet list (`Type 0, Type 1, ...`, `High, Medium, Low`) survive. To keep a dropdown, convert it to an in-sheet list in the template.

## 5. Keeping the standards in step

The engineering standards exist in two copies: `databricks_dbt_engineering_standards.md` in this folder and the Claude Doc "Databricks + dbt Engineering Standards". As of 3 Nov 2026 the two have the same content, including sections 12, 13 and 16. The only differences are in how they display: the markdown file draws the reference architecture as a Mermaid diagram, and the byline is plain text. They are separate copies, so a change to one must be made to the other by hand. Treat the markdown file as the master copy.
