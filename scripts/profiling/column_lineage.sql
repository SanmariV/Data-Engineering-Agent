-- Column lineage edges for every table the dbt project writes.
-- Used by build_information_matrix.py to trace each gold/silver column back
-- to its bronze source. Read-only: queries Unity Catalog system tables.
-- Parameters: $catalogs (quoted, comma separated), $lookback_days
select distinct
    lower(source_table_full_name) as source_table,
    lower(source_column_name) as source_column,
    lower(target_table_full_name) as target_table,
    lower(target_column_name) as target_column
from system.access.column_lineage
where
    target_table_catalog in ($catalogs)
    and source_table_full_name is not null
    and source_column_name is not null
    and target_column_name is not null
    and event_date >= date_sub(current_date(), $lookback_days)
