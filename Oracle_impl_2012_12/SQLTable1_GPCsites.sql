---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                                    Code producing Table 1:                                          -----  
-----           Study sample, flag for established patient, T2DM sample, Pregnancy events                 -----  
--------------------------------------------------------------------------------------------------------------- 
/* Tables used in this code: 
DIAGNOSIS,ENCOUNTER,DEMOGRAPHIC,PROCEDURES,LAB_RESULT_CM,PRESCRIBING tables from PCORNET.

Assumes all patient and encounter data is available in the GPC PCORNET CDM tables.

*/

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                          Part 1: Defining Denominator or Study Sample                               -----  
--------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------
-----                People with at least two encounters recorded on different days                       -----
-----                                                                                                     -----
-----                       Encounter should meet the following requerements:                             -----
-----    Patient must be 18 years old >= age <= 89 years old during the encounter day.                    -----
-----    Encounter should be encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',                 -----
-----    'INPATIENT HOSPITAL STAY', 'OBSERVATIONAL STAY', 'NON-ACUTE INSTITUTIONAL STAY'.                 -----
-----                                                                                                     -----
-----          The date of the first encounter and total number of encounters is collected.               -----
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------

CREATE TABLE NextD_eligible_encounters AS
WITH encs_with_age_at_visit AS (
   SELECT e.PATID
         ,e.ENCOUNTERID 
         ,(e.ADMIT_DATE - d.BIRTH_DATE) / 365.25 AS age_at_visit
         ,e.ADMIT_DATE
         ,e.ENC_TYPE
   FROM "&&PCORNET_CDM".ENCOUNTER e
   JOIN "&&PCORNET_CDM".DEMOGRAPHIC d ON e.PATID = d.PATID
), summarized_encounters AS (
   SELECT PATID
         ,ENCOUNTERID
         ,ADMIT_DATE
         ,count(DISTINCT TRUNC(ADMIT_DATE)) OVER (PARTITION BY PATID) AS cnt_distinct_enc_days
         ,row_number() OVER (PARTITION BY PATID ORDER BY ADMIT_DATE) AS rn
         ,ENC_TYPE
         ,age_at_visit
   FROM encs_with_age_at_visit
   WHERE age_at_visit between 18 AND 89
   AND   ENC_TYPE in ('IP', 'ED','IS','OS','AV') 
   AND   ADMIT_DATE BETWEEN DATE '2010-01-01' AND CURRENT_DATE -- alter date range if not using the study defaults
)
SELECT PATID
      ,ENCOUNTERID
      ,ADMIT_DATE
      ,cnt_distinct_enc_days
      ,rn
      ,ENC_TYPE
      ,age_at_visit
FROM summarized_encounters
WHERE cnt_distinct_enc_days >= 2;
;


CREATE TABLE NextD_first_visit AS
SELECT PATID,
       ADMIT_DATE AS NextD_first_visit
FROM NextD_eligible_encounters
WHERE rn = 1;

