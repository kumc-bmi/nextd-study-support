---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                             Part 8: Procedures for the study sample                                 -----  
--------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. PROCEDURES and DEMOGRAPHIC table from PCORNET. */
---------------------------------------------------------------------------------------------------------------
-----                            Declare study time frame variables:                                      -----
DECLARE @studyTimeRestriction int;declare @UpperTimeFrame DATE; declare @LowerTimeFrame DATE;
-----                             Specify time frame and age limits                                       -----
--Set extraction time frame below. If time frames not set, the code will use the whole time frame available from the database
set @LowerTimeFrame='2010-01-01';
set @UpperTimeFrame=getdate();/* insert here thw end exctraction date from iRB*/
--set age restrictions:
declare @UpperAge int; declare @LowerAge int;set @UpperAge=89; set @LowerAge=18;
---------------------------------------------------------------------------------------------------------------
select i.PATID,i.ENCOUNTERID,i.PROCEDURESID,i.ENC_TYPE,i.ADMIT_DATE_YEAR,i.ADMIT_DATE_MONTH,i.DAYS_from_FirstEncounter_Date1,
i.PX_DATE_YEAR,i.PX_DATE_MONTH,i.DAYS_from_FirstEncounter_Date2,i.PX,i.PX_TYPE,i.PX_SOURCE
into #NextD_PROCEDURES_FINAL
from (select c.PATID,b.ENCOUNTERID,b.PROCEDURESID,b.ENC_TYPE,year(b.ADMIT_DATE) as ADMIT_DATE_YEAR,month(b.ADMIT_DATE) as ADMIT_DATE_MONTH,datediff(d,c.FirstVisit,b.ADMIT_DATE) as DAYS_from_FirstEncounter_Date1,
b.PROVIDERID,year(b.PX_DATE) as PX_DATE_YEAR,month(b.PX_DATE) as PX_DATE_MONTH,datediff(d,c.FirstVisit,b.PX_DATE) as DAYS_from_FirstEncounter_Date2,b.PX,b.PX_TYPE ,b.PX_SOURCE
	  from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
	  left join /* provide name of PCORNET table PROCEDURES here: */ [capricorn].[dbo].[PROCEDURES] b on c.PATID=b.PATID 
	  left join /* provide name of PCORNET table DEMOGRAPPHIC here: */ capricorn.dbo.DEMOGRAPHIC d on c.PATID=d.PATID
	  where (datediff(yy,d.BIRTH_DATE,b.ADMIT_DATE) <= @UpperAge and datediff(yy, d.BIRTH_DATE,b.ADMIT_DATE) >= @LowerAge) and b.ADMIT_DATE >= @LowerTimeFrame and b.ADMIT_DATE <= @UpperTimeFrame
) i;
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_PROCEDURES_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------