---------------------------------------------------------------------------------------------------------------
-----                    Part 5: Vital signs for the study sample                              -----  
---------------------------------------------------------------------------------------------------------------
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. VITAL and DEMOGRAPHIC table from PCORNET.
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
select i.PATID,i.VITALID,i.ENCOUNTERID,i.VITAL_SOURCE,i.HT,i.WT,i.DIASTOLIC,i.SYSTOLIC,i.SMOKING,i.MEASURE_DATE
into #NextD_VITAL
from (select c.[PATID],b.[VITALID],b.[ENCOUNTERID],
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C1,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C2,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C3,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C4,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C5,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C6,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C7,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C8,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C9,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.MEASURE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C10,
		b.VITAL_SOURCE,b.HT,b.WT,b.DIASTOLIC,b.SYSTOLIC,b.SMOKING,b.MEASURE_DATE
		from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
		left join /* provide name of PCORNET table VITAL here: */  [capricorn].[dbo].[VITAL] b on c.PATID=b.PATID
		left join /* provide name of PCORNET table DEMOGRAPPHIC here: */ [capricorn].[dbo].[DEMOGRAPHIC] d on c.PATID=d.PATID 
		where (datediff(yy,d.BIRTH_DATE,b.MEASURE_DATE) <= @UpperAge and datediff(yy, d.BIRTH_DATE,b.MEASURE_DATE) >= @LowerAge) and b.MEASURE_DATE >= @LowerTimeFrame and b.MEASURE_DATE <= @UpperTimeFrame
	) i
where i.C1=0 and i.C1=0 and i.C2=0 and i.C3=0 and i.C4=0 and i.C5=0 and i.C6=0 and i.C7=0 and i.C8=0 and i.C9=0 and i.C10=0;
---------------------------------------------------------------------------------------------------------------
select d.GLOBALID,i.VITALID,i.ENCOUNTERID,i.VITAL_SOURCE,i.HT,i.WT,i.DIASTOLIC,i.SYSTOLIC,i.SMOKING,i.MEASURE_DATE,/*insert site label here:*/ 'SomeLabele' as SITELABEL
into #NextD_VITAL_FINAL
from #NextD_VITAL i join  /* provide name the table containing c.PATID,Hashes, and Global patient id*/ #GlobalIDtable d on i.PATID=d.CAP_ID;
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_VITAL_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------