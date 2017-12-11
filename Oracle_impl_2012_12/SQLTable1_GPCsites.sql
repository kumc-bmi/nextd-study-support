---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                                    Code producing Table 1:                                          -----  
-----           Study sample, flag for established patient, T2DM sample, Pregnancy events                 -----  
--------------------------------------------------------------------------------------------------------------- 
/* Tables used in this code: 
DIAGNOSIS,ENCOUNTER,DEMOGRAPHIC,PROCEDURES,LAB_RESULT_CM,PRESCRIBING tables from PCORNET.

Assumes all patient and encounter data is available in the GPC PCORNET CDM tables (this is not necessarily the
case for CAPRICORN sites which need to query additional tables linking CAP_ID to PCORNET PATID)

*/

CREATE TABLE NextD_eligible_encounters AS
WITH encs_with_age_at_visit AS (
   SELECT e.PATID
         ,e.ENCOUNTERID 
         ,(e.ADMIT_DATE - d.BIRTH_DATE) / 365.25 AS age_at_visit
         ,e.ADMIT_DATE
         ,e.ENC_TYPE
   FROM "&&PCORNET_CDM".ENCOUNTER e
   JOIN "&&PCORNET_CDM".DEMOGRAPHIC d ON e.PATID = d.PATID
)
SELECT PATID
      ,ENCOUNTERID
      ,ADMIT_DATE
      ,ENC_TYPE
      ,age_at_visit
FROM encs_with_age_at_visit
WHERE age_at_visit between 18 AND 89
AND   ENC_TYPE in ('IP', 'ED','IS','OS','AV') 
/*
AND   ADMIT_DATE BETWEEN "&&LowerTimeBound" AND "&&UpperTimeBound"
*/
;