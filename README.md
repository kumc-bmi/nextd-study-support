# Natural experiments for translation in diabetes (NEXT-D)

This is code to support the NEXT-D study.

Inital code by Al'ona Furmanchuk with Dan Connolly.
All contributors:
 - Al'ona Furmanchuk <alona.furmanchuk@northwestern.edu>, <furmanchuk@icnanotox.org>
 - Brennan Connolly <bconnolly@kumc.edu>
 - Dan Connolly <dckc@madmode.com>, <dconnolly@kumc.edu>
 - George Kowalski <gkowalski@mcw.edu>
 - Mei Liu <meiliu@kumc.edu>
 - Alex Stoddard <astoddard@mcw.edu>

See also:

 - [NEXT-D Data Request Detail](https://informatics.gpcnetwork.org/trac/Project/attachment/ticket/539/NEXT-D_Request%20for%20Data_Detailed_12.1.16.docx) draft of Nov 15
 - [Ticket #546](https://informatics.gpcnetwork.org/trac/Project/ticket/546)
 - [Ticket #545](https://informatics.gpcnetwork.org/trac/Project/ticket/545)


## Implemenation overview

NEXT-D query code targets PCORNET CDM implementations, originally developed against a SQLServer (see NextD_Dropbox_code) CDM by Al'ona Furmanchuk and then ported to Oracle (see Oracle_impl).

The SQLServer implementation using local temp tables. These are not implemented by Oracle which uses global temp tables. As of 2017-12 the Oracle implementation uses realized tables. The script "clean_build_tables.sql" in the Oracle_impl/ folder can be used to to clean up these realized tables before a re-run of "SQLTable1_GPCsites.sql".

Oracle sites may wish to create a separate NEXT-D schema with select priveleges on their CDM schema to segregate NEXT-D specific work.

## I2B2 sourced labs
The Oracle implementation from MCW as of 2017-12-18 assumes all labs are available (especially fasting and random glucose for Table1 generation) from PCORNet CDM "LAB_RESULT_CM" table. A 'TODO' placeholder section is in the file "SQLTable1_GPCsites.sql" which will need implementation where these labs are to be taken from I2B2. LOINC codes are specified in the NextD Dropbox documentation (not in this github repo), but should match those used in the PCORNET CDM code.

## Correct dates assumed
Note both the PCORNET CDM code and any I2B2 extraction assumes non-offset dates are available, or that code will be modified to join source tables with the appropriate per patient date correction to apply.

## Site specific data
Extraction code (see the NextD_Dropbox_code) will be added to the Oracle_impl. 
But note Provider characterization (via NPI taxonomy code), Visit Financial Class and geo-coding data are not part of the CDM spec and so site specific work will be needed to implement these.


## To run Oracle SQLTable1_GPCsites.sql
Oracle code is in Oracle_impl/SQLTable1_GPCsites.sql
  - Either modify SQLTable1_GPCsites.sql to reference your specific CDM schema (replacing all references to "&&PCORNET_CDM""), or rely on SqlPlus variable substition if that is your Oracle client of choice.
  
Extraction code for referencing study Table1 (called "FinalStatTable1" in all SQL code) can be reviewed in "NextD_Dropbox_code", better documented GPC specific versions can be expected to be added to "Oracle_impl".

## Study Info

 - Principal Investigators:
   - Bernard S. Black, JD, MA
   - Abel N. Kho, MD
 - Co-Investigators:
   - Laura J. Rasmussen-Torvik, PhD, MPH, FAHA
   - John Meurer, MD, MBA
   - Russ Waitman, PhD
   - Mei Liu, PhD
 - [Nov 2014 study protocol](http://listserv.kumc.edu/pipermail/gpc-dev/attachments/20161205/83a32ac8/attachment-0001.docx)
