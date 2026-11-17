# records_to_df() warns once about unconvertible columns

    Code
      out <- records_to_df(records, columns)
    Condition
      Warning:
      Can't convert 1 column to the type declared in Grist.
      i Returned a without type conversion.
      i Use `convert = "basic"` to skip type conversion.

# unknown columns are rejected or dropped

    Code
      check_record_columns(data, columns, grist_write_options())
    Condition
      Error:
      ! `data` has 1 column not in the Grist table.
      x Unknown column: b.
      i Use `grist_write_options(unknown_cols = "drop")` to ignore unknown columns.

