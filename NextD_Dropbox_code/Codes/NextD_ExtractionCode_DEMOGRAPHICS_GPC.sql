---------------------------------------------------------------------------------------------------------------
-----                            Part 1: Demographics for the study sample                                -----  
--------------------------------------------------------------------------------------------------------------- 
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. Demographics table from PCORNET.
3. External to PCORNET table (#MaritalStatusTable) with marital status on patients in study sample. */
--------------------------------------------------------------------------------------------------------------- 
select c.PATID,year(a.BIRTH_DATE) as BIRTH_DATE_YEAR,month(a.BIRTH_DATE) as BIRTH_DATE_MONTH,datediff(d,c.FirstVisit,a.BIRTH_DATE) as DAYS_from_FirstEncounter_Date,a.SEX,a.RACE,a.HISPANIC--,b.MaritalStatus 
into #NextD_DEMOGRAPHIC_FINAL
from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
left join /* provide name of PCORNET table DEMOGRAPHIC here: */ [capricorn].[dbo].[DEMOGRAPHIC] a on c.PATID =a.PATID 
left join /* provide name of external source table with marital status information here: */ #MaritalStatusTable b on c.PATID =b.PATID;
--------------------------------------------------------------------------------------------------------------- 
--------------------------------------------------------------------------------------------------------------- 
/* Save #NextD_DEMOGRAPHIC_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
--------------------------------------------------------------------------------------------------------------- 
