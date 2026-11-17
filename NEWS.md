# gristmillr 0.0.0.9000

* Initial development version with document handles (`grist_doc()`), options
  objects and `grist_request()` for building authenticated requests.
* `grist_tables()`, `grist_table_create()`, `grist_columns()`,
  `grist_columns_add()` and `grist_columns_modify()` read and change a
  document's schema.
* `grist_records()`, `grist_records_add()`, `grist_records_update()` and
  `grist_records_delete()` read and write records with a `convert` enum
  (`"auto"`, `"basic"` or `"raw"`). `grist_sql()` and `grist_count()` run SQL
  queries.
