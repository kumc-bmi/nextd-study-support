## Implemenation overview

NEXT-D query code targets PCORNET CDM implementations, originally developed against a SQLServer (see SQLServer_impl) CDM by Al'ona Furmanchuk and then ported to Oracle (see Oracle_impl).

The SQLServer implementation using local temp tables. These are not implemented by Oracle which uses global temp tables. The Oracle implementation therefore has "init_Oracle_temp_tables_ddl.sql" to define these tables. The definitions of these tables (but note their data contents) will persist in the Oracle schema used. 

Oracle sites may wish to create a separate NEXT-D schema with select priveleges on their CDM schema to segregate 
NEXT-D specific work.

### Reference code sets
Common code references for lab and medication are in ref_code_table_data and will need to be loaded into their corresponding tables in the NEXT-D/CDM schema when required by subsquent data analysis and extract steps.

_These data are not required for the "Table1" extract due 2017-09-05_ (see [Ticket:545](https://informatics.gpcnetwork.org/trac/Project/ticket/545))

## Table 1 subset extraction (due 2017-09-05)

SQLServer code has not been updated yet for this.

Oracle code is in Oracle_impl/NextD_table1.sql. 
  - First run init_Oracle_temp_tables_ddl.sql (errors from TRUNCATE and DROP can be ignored on an initial run) 
  - Either modify NextD_table1.sql to reference your specific CDM schema (replacing all references to "&&PCORNET_CDM""), or rely on SqlPlus variable substition if that is your Oracle client of choice.
  - Run NextD_table1.sql
  - Extract the "SubTable1_for_export" result table and upload to REDCap.