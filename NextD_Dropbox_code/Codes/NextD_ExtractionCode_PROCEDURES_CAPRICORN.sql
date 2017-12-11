---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                             Part 8: Procedures for the study sample                                 -----  
--------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. PROCEDURES and DEMOGRAPHIC table from PCORNET.
3. Tabel with mapping (named here #GlobalIDtable) between PCORNET IDs and Global patient IDs provided by MRAIA. */
---------------------------------------------------------------------------------------------------------------
-----                            Declare study time frame variables:                                      -----
DECLARE @studyTimeRestriction int;declare @UpperTimeFrame DATE; declare @LowerTimeFrame DATE;
-----                             Specify time frame and age limits                                       -----
--Set extraction time frame below. If time frames not set, the code will use the whole time frame available from the database
set @LowerTimeFrame='2011-01-01';
set @UpperTimeFrame=getdate();/* insert here thw end exctraction date from iRB*/
--set age restrictions:
declare @UpperAge int; declare @LowerAge int;set @UpperAge=89; set @LowerAge=18;
---------------------------------------------------------------------------------------------------------------
select i.PATID,i.ENCOUNTERID,i.PROCEDURESID,i.ENC_TYPE,i.ADMIT_DATE,i.PX_DATE,i.PX,i.PX_TYPE,i.PX_SOURCE
into #NextD_PROCEDURES
from (select c.PATID,b.ENCOUNTERID,b.PROCEDURESID,b.ENC_TYPE,b.ADMIT_DATE,b.PROVIDERID,b.PX_DATE,b.PX,b.PX_TYPE ,b.PX_SOURCE
	  from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
	  left join /* provide name of PCORNET table PROCEDURES here: */ [capricorn].[dbo].[PROCEDURES] b on c.PATID=b.PATID 
	  left join /* provide name of PCORNET table DEMOGRAPPHIC here: */ capricorn.dbo.DEMOGRAPHIC d on c.PATID=d.PATID
	  where (datediff(yy,d.BIRTH_DATE,b.ADMIT_DATE) <= @UpperAge and datediff(yy, d.BIRTH_DATE,b.ADMIT_DATE) >= @LowerAge) and b.ADMIT_DATE >= @LowerTimeFrame and b.ADMIT_DATE <= @UpperTimeFrame
) i;
---------------------------------------------------------------------------------------------------------------
select d.GLOBALID,i.ENCOUNTERID,i.PROCEDURESID,i.ENC_TYPE,i.ADMIT_DATE,i.PX_DATE,i.PX,i.PX_TYPE,i.PX_SOURCE,/*insert site label here:*/ 'SomeLabele' as SITELABEL
into #NextD_PROCEDURES_FINAL
from #NextD_PROCEDURES i join  /* provide name the table containing c.PATID,Hashes, and Global patient id*/ #GlobalIDtable d on i.CAP_ID=c.PATID;
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_PROCEDURES_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------