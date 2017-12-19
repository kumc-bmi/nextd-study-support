---------------------------------------------------------------------------------------------------------------
-----                            Part 1: Demographics for the study sample                                -----  
--------------------------------------------------------------------------------------------------------------- 
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. Demographics table from PCORNET.
3. External source table (#MaritalStatusTable) with marital status on patients in study sample.
4. Tabel with mapping (nmaed here #GlobalIDtable) between PCORNET IDs and Global patient IDs provided by MRAIA. */
--------------------------------------------------------------------------------------------------------------- 
select c.PATID,a.BIRTH_DATE,a.SEX,a.RACE,a.HISPANIC--,b.MaritalStatus 
into #NextD_DEMOGRAPHIC
from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
left join /* provide name of PCORNET table DEMOGRAPHIC here: */ [capricorn].[dbo].[DEMOGRAPHIC] a on c.PATID =a.PATID 
left join /* provide name of external source table with marital status information here: */ #MaritalStatusTable b on c.PATID =b.PATID;
--------------------------------------------------------------------------------------------------------------- 
select d.GLOBALID,a.BIRTH_DATE,a.SEX,a.RACE,a.HISPANIC,a.MaritalStatus,/*insert site label here:*/ 'SomeLabele' as SITELABEL 
into #NextD_DEMOGRAPHIC_FINAL
from  #NextD_DEMOGRAPHIC a
join  /* provide name the table containing c.PATID,Hashes, and Global patient id*/ #GlobalIDtable d on a.PATID=d.CAP_ID;
--------------------------------------------------------------------------------------------------------------- 
/* Save #NextD_DEMOGRAPHIC_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
--------------------------------------------------------------------------------------------------------------- 
