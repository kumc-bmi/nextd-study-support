---------------------------------------------------------------------------------------------------------------
-----                    Part 3: Prescibed medications for the study sample                               -----  
--------------------------------------------------------------------------------------------------------------- 
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. PRESCRIBING and DEMOGRAPHIC tables from PCORNET.
3. External to PCORNET table CAP_ENCOUNTERS with encounters from whole data warehouse.*/
---------------------------------------------------------------------------------------------------------------
-----                            Declare study time frame variables:
DECLARE @studyTimeRestriction int;declare @UpperTimeFrame DATE; declare @LowerTimeFrame DATE;
-----                             Specify time frame and age limits                                       -----
--Set extraction time frame below. If time frames not set, the code will use the whole time frame available from the database
set @LowerTimeFrame='2010-01-01';
set @UpperTimeFrame=getdate();/* insert here thw end exctraction date from iRB*/
--set age restrictions:
declare @UpperAge int; declare @LowerAge int;set @UpperAge=89; set @LowerAge=18;
---------------------------------------------------------------------------------------------------------------
select i.PATID,i.ENCOUNTERID,i.PRESCRIBINGID,i.RXNORM_CUI,i.RX_ORDER_DATE,i.RX_PROVIDERID,i.RX_DAYS_SUPPLY,i.RX_REFILLS ,i.RX_BASIS,i.RAW_RX_MED_NAME  
into #NextD_PRESCRIBING_FINAL
from (select c.PATID,a.ENCOUNTERID,b.PRESCRIBINGID,b.RXNORM_CUI,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C1,
		case when c.[Pregnancy2_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy2_Date]))>1 then 0 when c.[Pregnancy2_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy2_Date]))<=1 then 1 when c.[Pregnancy2_Date] is NULL then 0 end as C2,
		case when c.[Pregnancy3_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy3_Date]))>1 then 0 when c.[Pregnancy3_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy3_Date]))<=1 then 1 when c.[Pregnancy3_Date] is NULL then 0 end as C3,
		case when c.[Pregnancy4_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy4_Date]))>1 then 0 when c.[Pregnancy4_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy4_Date]))<=1 then 1 when c.[Pregnancy4_Date] is NULL then 0 end as C4,
		case when c.[Pregnancy5_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy5_Date]))>1 then 0 when c.[Pregnancy5_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy5_Date]))<=1 then 1 when c.[Pregnancy5_Date] is NULL then 0 end as C5,
		case when c.[Pregnancy6_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy6_Date]))>1 then 0 when c.[Pregnancy6_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy6_Date]))<=1 then 1 when c.[Pregnancy6_Date] is NULL then 0 end as C6,
		case when c.[Pregnancy7_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy7_Date]))>1 then 0 when c.[Pregnancy7_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy7_Date]))<=1 then 1 when c.[Pregnancy7_Date] is NULL then 0 end as C7,
		case when c.[Pregnancy8_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy8_Date]))>1 then 0 when c.[Pregnancy8_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy8_Date]))<=1 then 1 when c.[Pregnancy8_Date] is NULL then 0 end as C8,
		case when c.[Pregnancy9_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy9_Date]))>1 then 0 when c.[Pregnancy9_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy9_Date]))<=1 then 1 when c.[Pregnancy9_Date] is NULL then 0 end as C9,
		case when c.[Pregnancy10_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy10_Date]))>1 then 0 when c.[Pregnancy10_Date] is not NULL and ABS(datediff(yy,b.RX_ORDER_DATE,c.[Pregnancy10_Date]))<=1 then 1 when c.[Pregnancy10_Date] is NULL then 0 end as C10,
		year(b.RX_ORDER_DATE) as PX_ORDER_DATE_YEAR,month(b.RX_ORDER_DATE) as PX_ORDER_DATE_MONTH,datediff(d,c.FirstVisit,b.RX_ORDER_DATE) as DAYS_from_FirstEncounter_Date,b.RX_PROVIDERID,b.RX_DAYS_SUPPLY,b.RX_REFILLS ,b.RX_BASIS,b.RAW_RX_MED_NAME
		from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
		left join /* provide name of PCORNET table ENCOUNTER here: */ [capricorn].[dbo].[CAP_ENCOUNTERS] a on c.PATID=a.CAP_ID
		left join /* provide name of PCORNET table ENCOUNTER here: */ [capricorn].[dbo].[PRESCRIBING] b on c.PATID=b.PATID 
		left join /* provide name of PCORNET table DEMOGRAPPHIC here: */ [capricorn].[dbo].[DEMOGRAPHIC] d on c.PATID=d.PATID
		where (datediff(yy,d.BIRTH_DATE,b.RX_ORDER_DATE) <= @UpperAge and datediff(yy, d.BIRTH_DATE,b.RX_ORDER_DATE) >= @LowerAge) and b.RX_ORDER_DATE >= @LowerTimeFrame and b.RX_ORDER_DATE <= @UpperTimeFrame
) i
where i.C1=0 and i.C1=0 and i.C2=0 and i.C3=0 and i.C4=0 and i.C5=0 and i.C6=0 and i.C7=0 and i.C8=0 and i.C9=0 and i.C10=0;
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_PRESCRIBING_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------