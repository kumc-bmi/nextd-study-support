---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                             Part 9: DEATH_CAUSE for the study sample                                -----  
--------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------
/* Tables for this eaxtraction: 
1. Table 1 (named here [NextD].[dbo].[FinalStatTable1]) with Next-D study sample IDs. See separate SQL code for producing this table.
2. DEATH_CAUSE table from PCORNET. */
---------------------------------------------------------------------------------------------------------------
select c.PATID,b.DEATH_CAUSE, b.DEATH_CAUSE_CODE,b.DEATH_CAUSE_TYPE ,b.DEATH_CAUSE_SOURCE ,b.DEATH_CAUSE_CONFIDENCE 
into #NextD_DEATH_CAUSE_FINAL
from /* provide name of table 1 here: */ [NextD].[dbo].[FinalStatTable1] c 
left join /* provide name of PCORNET table DEATH_CAUSE here: */ [capricorn].[dbo].[DEATH_CAUSE] b on c.PATID=b.PATID;
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
/* Save #NextD_DEATH_CAUSE_FINAL as csv file. 
Use "|" symbol as field terminator and 
"ENDALONAEND" as row terminator. */ 
---------------------------------------------------------------------------------------------------------------