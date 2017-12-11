---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                    Part 4: Dispensing medications for the study sample                              -----  
--------------------------------------------------------------------------------------------------------------- 
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. DISPENSING and DEMOGRAPHIC table from PCORNET.*/
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
select i.PATID,i.DISPENSINGID,i.NDC,i.DISPENSE_DATE_YEAR,i.DISPENSE_DATE_MONTH,i.DAYS_from_FirstEncounter_Date,i.DISPENSE_SUP,i.DISPENSE_AMT 
into #NextD_DISPENSING_FINAL
from (select c.PATID,b.DISPENSINGID,b.NDC,
case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C1,
case when c.[Pregnancy2_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy2_Date]))>1 then 0 when c.[Pregnancy2_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy2_Date]))<=1 then 1 when c.[Pregnancy2_Date] is NULL then 0 end as C2,
case when c.[Pregnancy3_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy3_Date]))>1 then 0 when c.[Pregnancy3_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy3_Date]))<=1 then 1 when c.[Pregnancy3_Date] is NULL then 0 end as C3,
case when c.[Pregnancy4_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy4_Date]))>1 then 0 when c.[Pregnancy4_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy4_Date]))<=1 then 1 when c.[Pregnancy4_Date] is NULL then 0 end as C4,
case when c.[Pregnancy5_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy5_Date]))>1 then 0 when c.[Pregnancy5_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy5_Date]))<=1 then 1 when c.[Pregnancy5_Date] is NULL then 0 end as C5,
case when c.[Pregnancy6_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy6_Date]))>1 then 0 when c.[Pregnancy6_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy6_Date]))<=1 then 1 when c.[Pregnancy6_Date] is NULL then 0 end as C6,
case when c.[Pregnancy7_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy7_Date]))>1 then 0 when c.[Pregnancy7_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy7_Date]))<=1 then 1 when c.[Pregnancy7_Date] is NULL then 0 end as C7,
case when c.[Pregnancy8_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy8_Date]))>1 then 0 when c.[Pregnancy8_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy8_Date]))<=1 then 1 when c.[Pregnancy8_Date] is NULL then 0 end as C8,
case when c.[Pregnancy9_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy9_Date]))>1 then 0 when c.[Pregnancy9_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy9_Date]))<=1 then 1 when c.[Pregnancy9_Date] is NULL then 0 end as C9,
case when c.[Pregnancy10_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy10_Date]))>1 then 0 when c.[Pregnancy10_Date] is not NULL and ABS(datediff(yy,b.DISPENSE_DATE,c.[Pregnancy10_Date]))<=1 then 1 when c.[Pregnancy10_Date] is NULL then 0 end as C10,
year(b.DISPENSE_DATE) as DISPENSE_DATE_YEAR,month(b.DISPENSE_DATE) as DISPENSE_DATE_MONTH,datediff(d,c.FirstVisit,b.DISPENSE_DATE) as DAYS_from_FirstEncounter_Date,b.DISPENSE_SUP,b.DISPENSE_AMT
from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
left join /* provide name of PCORNET table ENCOUNTER here: */ [capricorn].[dbo].[DISPENSING] b on c.PATID=b.PATID 
left join /* provide name of PCORNET table DEMOGRAPPHIC here: */ capricorn.dbo.DEMOGRAPHIC d on c.PATID=d.PATID
where (datediff(yy,d.BIRTH_DATE,b.DISPENSE_DATE) <= @UpperAge and datediff(yy, d.BIRTH_DATE,b.DISPENSE_DATE) >= @LowerAge) and b.DISPENSE_DATE >= @LowerTimeFrame and b.DISPENSE_DATE <= @UpperTimeFrame
) i
where i.C1=0 and i.C1=0 and i.C2=0 and i.C3=0 and i.C4=0 and i.C5=0 and i.C6=0 and i.C7=0 and i.C8=0 and i.C9=0 and i.C10=0;
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_DISPENSING_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------