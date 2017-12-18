---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                             Part 6: Labs for the study sample                                       -----  
--------------------------------------------------------------------------------------------------------------- 
--------------------------------------------------------------------------------------------------------------- 
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. LAB_RESULT_CM and DEMOGRAPHIC table from PCORNET.
3. External to PCORNET table CAP_LABS with the labs of interest.*/
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
--Part1: Labs from PCORNET:
select i.PATID,i.LAB_RESULT_CM_ID,i.ENCOUNTERID,i.LAB_ORDER_DATE_YEAR,i.LAB_ORDER_DATE_MONTH,i.DAYS_from_FirstEncounter_Date1,
i.SPECIMEN_ORDER_DATE_YEAR,i.SPECIMEN_ORDER_DATE_MONTH,i.DAYS_from_FirstEncounter_Date2,i.RESULT_NUM,i.RESULT_UNIT,i.LAB_LOINC,i.LAB_PX_TYPE,i.RESULT_LOC,i.LAB_NAME,i.RESULT_MODIFIER,i.RAW_RESULT,i.RAW_LAB_NAME 
into #LABSpart1 
from 
(select c.PATID,b.LAB_RESULT_CM_ID,b.ENCOUNTERID,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C1,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C2,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C3,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C4,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C5,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C6,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C7,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C8,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C9,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C10,
		year(b.LAB_ORDER_DATE) as LAB_ORDER_DATE_YEAR,month(b.LAB_ORDER_DATE) as LAB_ORDER_DATE_MONTH,datediff(d,c.FirstVisit,b.LAB_ORDER_DATE) as DAYS_from_FirstEncounter_Date1,
		year(b.SPECIMEN_ORDER_DATE) as SPECIMEN_ORDER_DATE_YEAR,month(b.SPECIMEN_ORDER_DATE) as SPECIMEN_ORDER_DATE_MONTH,datediff(d,c.FirstVisit,b.SPECIMEN_ORDER_DATE) as DAYS_from_FirstEncounter_Date2,
		b.RESULT_NUM,b.RESULT_UNIT,b.LAB_LOINC,b.LAB_PX_TYPE,b.RESULT_LOC,b.LAB_NAME,b.RESULT_MODIFIER,b.RAW_RESULT,b.RAW_LAB_NAME
		from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
		left join /* provide name of PCORNET table LAB_RESULT_CM here: */ [capricorn].[dbo].[LAB_RESULT_CM] b on c.PATID=b.PATID 
		left join /* provide name of PCORNET table DEMOGRAPPHIC here: */ capricorn.dbo.DEMOGRAPHIC d on c.PATID=d.PATID
		where b.RESULT_NUM is not NULL and b.LAB_NAME in ('A1C','LDL','CREATININE','HGB') and
		(datediff(yy,d.BIRTH_DATE,b.LAB_ORDER_DATE) <= @UpperAge and datediff(yy, d.BIRTH_DATE,b.LAB_ORDER_DATE) >= @LowerAge) and b.LAB_ORDER_DATE >= @LowerTimeFrame and b.LAB_ORDER_DATE <= @UpperTimeFrame
) i
where i.C1=0 and i.C1=0 and i.C2=0 and i.C3=0 and i.C4=0 and i.C5=0 and i.C6=0 and i.C7=0 and i.C8=0 and i.C9=0 and i.C10=0;
---------------------------------------------------------------------------------------------------------------
--Part2: Labs from CAPRICORN:
select i.PATID,i.LAB_RESULT_CM_ID,i.ENCOUNTERID,i.LAB_ORDER_DATE_YEAR,i.LAB_ORDER_DATE_MONTH,i.DAYS_from_FirstEncounter_Date1,
i.SPECIMEN_ORDER_DATE_YEAR,i.SPECIMEN_ORDER_DATE_MONTH,i.DAYS_from_FirstEncounter_Date2,i.RESULT_NUM,i.RESULT_UNIT,i.LAB_LOINC,i.LAB_PX_TYPE,i.RESULT_LOC,i.LAB_NAME,i.RESULT_MODIFIER,i.RAW_RESULT,i.RAW_LAB_NAME 
into #LABSpart2 
from 
(select c.PATID,b.LAB_RESULT_CM_ID,b.ENCOUNTERID,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C1,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C2,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C3,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C4,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C5,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C6,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C7,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C8,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C9,
		case when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))>1 then 0 when c.[Pregnancy1_Date] is not NULL and ABS(datediff(yy,b.LAB_ORDER_DATE,c.[Pregnancy1_Date]))<=1 then 1 when c.[Pregnancy1_Date] is NULL then 0 end as C10,
		year(b.LAB_ORDER_DATE) as LAB_ORDER_DATE_YEAR,month(b.LAB_ORDER_DATE) as LAB_ORDER_DATE_MONTH,datediff(d,c.FirstVisit,b.LAB_ORDER_DATE) as DAYS_from_FirstEncounter_Date1,
		year(b.SPECIMEN_ORDER_DATE) as SPECIMEN_ORDER_DATE_YEAR,month(b.SPECIMEN_ORDER_DATE) as SPECIMEN_ORDER_DATE_MONTH,datediff(d,c.FirstVisit,b.SPECIMEN_ORDER_DATE) as DAYS_from_FirstEncounter_Date2,
		b.VALUE_NUMERIC as RESULT_NUM,b.RESULT_UNIT,b.LAB_LOINC,b.LAB_PX_TYPE,b.RESULT_LOC,b.LAB_NAME,
		/*figure out proper column names in your i2b2 system for the following three variables:*/b.RESULT_MODIFIER,b.RAW_RESULT,b.RAW_LAB_NAME
		from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
		left join /* provide name of non-PCORNET table LAB_RESULT_CM here: */ [capricorn].[dbo].[CAP_LABS] b on c.PATID=b.CAP_ID 
		left join /* provide name of PCORNET table DEMOGRAPPHIC here: */ capricorn.dbo.DEMOGRAPHIC d on c.PATID=d.PATID
		where b.VALUE_NUMERIC is not NULL and b.LAB_LOINC in ('14647-2','2093-3','14646-4','18263-4','2085-9','12951-0','14927-8','2571-8','47210-0','17855-8','4548-4','4549-2','17856-6','41995-2','59261-8','62388-4','71875-9','54039-3',
                                                     '2345-7','2339-0','10450-5','17865-7','1554-5','6777-7','54246-4','2344-0','41652-9','1558-6','10450-5', '1554-5', '17865-7', '35184-1','14957-5','57369-1','53530-2','30003-8',
													 '43605-5','53531-0','11218-5','43607-1','63474-1','53532-8','14956-7','43606-3','56553-1','49023-5','58448-2','44292-1','14958-3','14959-1','59159-4','30000-4','30001-2','47558-2',
													 '13705-9','14585-4','1753-3','1754-1','1755-8','1757-4','20621-9','21059-1','9318-7','50949-7','32294-1','13032-8','13033-6','13034-4','13035-1','13036-9','13037-7','13038-5',
													 '13039-3','13040-1','13041-9','13042-7','13043-5','13044-3','13045-0','13859-4','13860-2','13861-0','14633-2','16501-9','16502-7','1986-9','25568-7','25569-5','25570-3','25571-1',
													 '25572-9','25573-7','25574-5','25575-2','25576-0','25577-8','25578-6','25579-4','25580-2','25581-0','25582-8','27408-4','27421-7','27839-0','35195-7','38249-9','38421-4','38422-2',
													 '38423-0','38424-8','38425-5','38426-3','42180-0','47583-0','47584-8','47585-5','47586-3','47587-1','47588-9','47589-7','47590-5','47591-3','47592-1','47593-9','47594-7','47595-4',
													 '47832-1','47833-9','47834-7','50461-3','50462-1','50463-9','50464-7','50465-4','50466-2','50467-0','50468-8','55918-7','55919-5','56516-8','56582-0','56583-8','56584-6','57376-6',
													 '57645-4','57646-2','57647-0','57648-8','57649-6','57650-4','57651-2','57894-8','58494-6','58495-3','58496-1','58497-9','58498-7','58499-5','58500-0','58501-8','58502-6','58503-4',
													 '58504-2','58505-9','58506-7','58507-5','58508-3','58509-1','58510-9','58511-7','58512-5','58513-3','58514-1','58515-8','58516-6','58517-4','58518-2','58519-0','58520-8','58521-6',
													 '58522-4','58686-7','58816-0','58841-8','58896-2','77610-4','77611-2','77612-0','77651-8','77652-6','53061-8','49779-2','33043-1','33903-6','2514-8','50557-8','5797-6','2514-8',
													 '33903-6','45225-0','45171-6','5265-4','63571-4','56687-7','8086-1','31547-3','34652-8','13927-9','33563-8','31209-0','56718-0','81155-4','32636-3','70253-0','70252-2','42501-7',
													 '13926-1','56540-8','58451-6','81725-4','72523-4','30347-9','83004-2','82660-2','31209-0','56718-0','81155-4','32636-3','70253-0','70252-2','76651-9') 
		and (datediff(yy,d.BIRTH_DATE,b.LAB_ORDER_DATE) <= @UpperAge and datediff(yy, d.BIRTH_DATE,b.LAB_ORDER_DATE) >= @LowerAge) and b.LAB_ORDER_DATE >= @LowerTimeFrame and b.LAB_ORDER_DATE <= @UpperTimeFrame
) i
where i.C1=0 and i.C1=0 and i.C2=0 and i.C3=0 and i.C4=0 and i.C5=0 and i.C6=0 and i.C7=0 and i.C8=0 and i.C9=0 and i.C10=0;
---------------------------------------------------------------------------------------------------------------
--Part3:Combine both tables into single LABS table:
select a.* into #NextD_allLABS_FINAL 
from (select * from #LABSpart1
	  union all 
	  select * from #LABSpart2 
	  ) a;
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_allLABS_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------