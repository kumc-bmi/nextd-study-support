---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                      Part 10: Socio-economic status for the study sample                            -----  
--------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. Side table (named here #SES) with census track labels.
3. Tabel with mapping (named here #GlobalIDtable) between PCORNET IDs and Global patient IDs provided by MRAIA. */
---------------------------------------------------------------------------------------------------------------
-----  Declare study time frame variables:
DECLARE @studyTimeRestriction int;declare @UpperTimeFrame DATE; declare @LowerTimeFrame DATE;
-----                             Specify time frame and age limits                                       -----
--Set extraction time frame below. If time frames not set, the code will use the whole time frame available from the database
set @LowerTimeFrame='2011-01-01';
set @UpperTimeFrame=getdate();/* insert here thw end exctraction date from iRB*/
--set age restrictions:
declare @UpperAge int; declare @LowerAge int;set @UpperAge=89; set @LowerAge=18;
---------------------------------------------------------------------------------------------------------------
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[CAPTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. Side table (named here #SES) with census track labels.
3. Tabel with mapping (named here #GlobalIDtable) between PCORNET IDs and Global patient IDs provided by MURAIA. */
---------------------------------------------------------------------------------------------------------------
select d.GLOBALID,b.GTRACT_ACS,/*insert site label here:*/ 'SomeLabele' as SITELABEL 
into #NextD_SES
from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
join  /* provide name the table containing c.PATID,Hashes, and Global patient id*/ #GlobalIDtable d on c.PATID=d.CAP_ID
left join /* provide name of non-PCORNET table with SES data here: */ #SES b on c.PATID=b.CAP_ID;
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_SES as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------