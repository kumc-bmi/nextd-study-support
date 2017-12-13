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


CREATE TABLE NextD_first_visit AS
SELECT PATID,
       ADMIT_DATE AS NextD_first_visit
FROM NextD_eligible_encounters
WHERE rn = 1;

CREATE INDEX NextD_first_visit_PATID_IDX ON NextD_first_visit(PATID);

---------------------------------------------------------------------------------------------------------------
-----                                    Part 2: Defining Pregnancy                                       -----
---------------------------------------------------------------------------------------------------------------
-----                             People with pregnancy-related encounters                                -----
-----                                                                                                     -----
-----                       Encounter should meet the following requerements:                             -----
-----           Patient must be 18 years old >= age <= 89 years old during the encounter day.             -----
-----                                                                                                     -----
-----                 The date of the first encounter for each pregnancy is collected.                    -----
---------------------------------------------------------------------------------------------------------------

-- Collect all pregnancy events
--  as per t-SQL code no ENC_TYPE filtering is done here for maximum coverage, confirming in communication with Alona

CREATE TABLE NextD_pregnancy_event_dates AS
WITH preg_related_dx AS (
   SELECT dia.PATID      AS PATID
         ,dia.ADMIT_DATE AS ADMIT_DATE
   FROM "&&PCORNET_CDM".DIAGNOSIS dia
   JOIN "&&PCORNET_CDM".DEMOGRAPHIC d ON dia.PATID = d.PATID
   WHERE
      -- miscarriage, abortion, pregnancy, birth and pregnancy related complications diagnosis codes diagnosis codes:
      (
        -- ICD9 codes
        (
          (   regexp_like(dia.DX,'^63[0-9]\.')
           or regexp_like(dia.DX,'^6[4-7][0-9]\.')
           or regexp_like(dia.DX,'^V2[2-3]\.')
           or regexp_like(dia.DX,'^V28\.')
          )
          AND dia.DX_TYPE = '09'
        )
        OR
        -- ICD10 codes
        (
          (   regexp_like(dia.DX,'^O')
           or regexp_like(dia.DX,'^A34\.')
           or regexp_like(dia.DX,'^Z3[34]\.')
           or regexp_like(dia.DX,'^Z36')
          )
          and dia.DX_TYPE = '10'
        )
      )
      -- age restriction
      AND
      (
        ((dia.ADMIT_DATE - d.BIRTH_DATE) / 365.25 ) BETWEEN 18 AND 89
      )
      -- time frame restriction
      AND
      (
         dia.ADMIT_DATE BETWEEN DATE '2010-01-01' AND CURRENT_DATE
      )
      -- eligible patients
      AND
      (
        EXISTS (SELECT 1 FROM NextD_first_visit v WHERE dia.PATID = v.PATID)
      )
), delivery_proc AS (
   SELECT  p.PATID       AS PATID
          ,p.ADMIT_DATE  AS ADMIT_DATE
    FROM "&&PCORNET_CDM".PROCEDURES  p
    JOIN "&&PCORNET_CDM".DEMOGRAPHIC d ON p.PATID = d.PATID
    WHERE
      -- Procedure codes
      (
          -- ICD9 codes
          (
            regexp_like(p.PX,'^7[2-5]\.')
            and p.PX_TYPE = '09'
          )
          OR
          -- ICD10 codes
          (
            regexp_like(p.PX,'^10')
            and p.PX_TYPE = '10'
          )
          OR
          -- CPT codes
          (
            regexp_like(p.PX,'^59[0-9][0-9][0-9]')
            and p.PX_TYPE='CH'
          )
      )
      -- age restriction
      AND
      (
        ((p.ADMIT_DATE - d.BIRTH_DATE) / 365.25 ) BETWEEN 18 AND 89
      )
      AND
      -- time frame restriction
      (
        p.ADMIT_DATE BETWEEN DATE '2010-01-01' AND CURRENT_DATE
      )
      AND
      -- eligible patients
      (
        EXISTS (SELECT 1 FROM NextD_first_visit v WHERE p.PATID = v.PATID)
      )
)
SELECT PATID, ADMIT_DATE
FROM preg_related_dx
UNION
SELECT PATID, ADMIT_DATE
FROM delivery_proc;

-- Find separate pregnancy events (separated by >= 12 months from prior event)
CREATE TABLE NextD_distinct_preg_events AS
WITH delta_pregnancies AS (
    SELECT PATID
          ,ADMIT_DATE
          ,round(months_between( ADMIT_DATE
                               , Lag(ADMIT_DATE, 1, NULL) OVER (PARTITION BY PATID ORDER BY ADMIT_DATE)
                               )) AS months_delta
    FROM NextD_pregnancy_event_dates
)
SELECT PATID
      ,ADMIT_DATE
      ,row_number() OVER (PARTITION BY PATID ORDER BY ADMIT_DATE) rn
FROM delta_pregnancies
WHERE months_delta IS NULL OR months_delta >= 12;

-- Transponse pregnancy table into single row per patient
CREATE TABLE NextD_FinalPregnancy AS
  SELECT *
  FROM
    (
     SELECT PATID, ADMIT_DATE, rn
     FROM NextD_distinct_preg_events
    )
    PIVOT (max(ADMIT_DATE) for (rn) in (1,2,3,4,5,6,7,8,9,10))
    ORDER BY PATID
;
