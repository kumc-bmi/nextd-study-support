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

-- Index needed for efficient masking of encounters
CREATE INDEX NextD_distinct_preg_event_idx ON NextD_distinct_preg_events(PATID, ADMIT_DATE);

-- Mask eligible encounters within 1 year of any distinct pregnancies
CREATE TABLE NextD_preg_masked_encounters AS
SELECT e.*
FROM NextD_eligible_encounters e
WHERE NOT EXISTS (SELECT 1
                  FROM NextD_distinct_preg_events pevent
                  WHERE pevent.PATID = e.PATID
                  AND abs(e.ADMIT_DATE - pevent.ADMIT_DATE) <= 365);

CREATE INDEX NextD_preg_masked_enc_idx ON NextD_preg_masked_encounters (ENCOUNTERID);

-- TODO -- TODO -- TODO
-- Oracle code equivalent to FinalStatTable01 generation
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                 Part3: Combine results from all parts of the code into final table:                 -----
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
/*select a.CAP_ID as PATID, b.FirstVisit, a.NumberOfPermutations as NumerOfVisits,
  -- x.EventDate as DMonsetDate,
   d.DEATH_DATE,
p.[1] as Pregnancy1_Date, p.[2] as Pregnancy2_Date, p.[3] as Pregnancy3_Date, p.[4] as Pregnancy4_Date, p.[5] as Pregnancy5_Date,
p.[6] as Pregnancy6_Date, p.[7] as Pregnancy7_Date, p.[8] as Pregnancy8_Date, p.[9] as Pregnancy9_Date, p.[10] as Pregnancy10_Date
into #FinalStatTable01
from #Denomtemp1 a left join #Denomtemp2 b on a.CAP_ID=b.CAP_ID
left join capricorn.dbo.CAP_DEATH d on a.CAP_ID=d.CAP_ID
left join #FinalPregnancy p on a.CAP_ID=p.PATID;
*/

-- TODO -- TODO -- TODO

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                                 Defining Deabetes Mellitus sample                                   -----
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----        People with HbA1c having two measures on different days within 2 years interval              -----
-----                                                                                                     -----
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 6.5 %.                                                                           -----
-----    Lab name is 'A1C' or                                                                             -----
-----    LOINC codes '17855-8', '4548-4','4549-2','17856-6','41995-2','59261-8','62388-4',                -----
-----    '71875-9','54039-3'                                                                              -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'OBSERVATIONAL STAY', 'NON-ACUTE INSTITUTIONAL STAY'.                 -----
-----                                                                                                     -----
-----    In this Oracle version of the code Patient age, encounter type and pregnancy masking is          -----
-----    accomplished by joining against the set of pregnancy masked eligible encounters                  -----
---------------------------------------------------------------------------------------------------------------

CREATE TABLE NextD_all_A1C AS
WITH A1C_LABS AS (
SELECT l.PATID
      ,l.LAB_ORDER_DATE
      ,l.LAB_NAME
      ,l.LAB_LOINC
      ,l.RESULT_NUM
      ,l.RESULT_UNIT
FROM "&&PCORNET_CDM".LAB_RESULT_CM l
WHERE ( l.LAB_NAME='A1C'
        OR
        l.LAB_LOINC IN ('17855-8', '4548-4','4549-2','17856-6','41995-2','59261-8','62388-4','71875-9','54039-3')
      )
      AND l.RESULT_NUM > 6.5
      AND l.RESULT_UNIT = 'PERCENT'
      AND EXISTS (SELECT 1 FROM NextD_preg_masked_encounters valid_encs
                           WHERE valid_encs.ENCOUNTERID = l.ENCOUNTERID)
)
SELECT * FROM A1C_LABS
ORDER BY PATID, LAB_ORDER_DATE;

-- take the first date of the earlist pair of A1C results on distinct days within two years of each other
CREATE TABLE NextD_A1C_final_FirstPair AS
WITH DELTA_A1C AS (
SELECT PATID
      ,LAB_ORDER_DATE
      ,CASE WHEN LEAD(TRUNC(LAB_ORDER_DATE), 1, NULL) OVER (PARTITION BY PATID ORDER BY LAB_ORDER_DATE) - TRUNC(LAB_ORDER_DATE) BETWEEN 1 AND 365 * 2 
           THEN 1
           ELSE 0
       END AS WITHIN_TWO_YEARS
FROM NextD_all_A1C
), A1C_WITHIN_TWO_YEARS AS (
SELECT PATID
      ,LAB_ORDER_DATE
      ,row_number() OVER (PARTITION BY PATID ORDER BY LAB_ORDER_DATE) AS rn
FROM DELTA_A1C
WHERE WITHIN_TWO_YEARS = 1
)
SELECT PATID
      , LAB_ORDER_DATE
FROM A1C_WITHIN_TWO_YEARS
WHERE rn = 1;

---------------------------------------------------------------------------------------------------------------
-----     People with fasting glucose having two measures on different days within 2 years interval       -----
-----                                                                                                     -----
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 126 mg/dL.                                                                       -----
-----    (LOINC codes '1558-6',  '10450-5', '1554-5', '17865-7','35184-1' )                               -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                   The first pair of labs meeting requerements is collected.                         -----
-----   The date of the first fasting glucose lab out the first pair will be recorded as initial event.   -----
---------------------------------------------------------------------------------------------------------------
-----                                    May not be available in PCORNET                                  -----
---------------------------------------------------------------------------------------------------------------
-----    In this Oracle version of the code Patient age, encounter type and pregnancy masking is          -----
-----    accomplished by joining against the set of pregnancy masked eligible encounters                  -----
---------------------------------------------------------------------------------------------------------------

CREATE TABLE NextD_all_FG AS
WITH FG_LABS AS (
SELECT l.PATID
      ,l.LAB_ORDER_DATE
      ,l.LAB_NAME
      ,l.LAB_LOINC
      ,l.RESULT_NUM
      ,l.RESULT_UNIT
FROM "&&PCORNET_CDM".LAB_RESULT_CM l
WHERE l.LAB_LOINC IN ('1558-6', '10450-5', '1554-5', '17865-7', '35184-1')
      AND l.RESULT_NUM >= 126
      AND UPPER(l.RESULT_UNIT) = 'MG/DL' -- PCORNET_CDM 3.1 standardizes on uppercase lab units
      AND EXISTS (SELECT 1 FROM NextD_preg_masked_encounters valid_encs
                           WHERE valid_encs.ENCOUNTERID = l.ENCOUNTERID)
)
SELECT * FROM FG_LABS
ORDER BY PATID, LAB_ORDER_DATE;

CREATE TABLE NextD_FG_final_FirstPair AS
WITH DELTA_FG AS (
SELECT PATID
      ,LAB_ORDER_DATE
      ,CASE WHEN LEAD(TRUNC(LAB_ORDER_DATE), 1, NULL) OVER (PARTITION BY PATID ORDER BY LAB_ORDER_DATE) - TRUNC(LAB_ORDER_DATE) BETWEEN 1 AND 365 * 2 
           THEN 1
           ELSE 0
       END AS WITHIN_TWO_YEARS
FROM NextD_all_FG
), FG_WITHIN_TWO_YEARS AS (
SELECT PATID
      ,LAB_ORDER_DATE
      ,row_number() OVER (PARTITION BY PATID ORDER BY LAB_ORDER_DATE) AS rn
FROM DELTA_FG
WHERE WITHIN_TWO_YEARS = 1
)
SELECT PATID
      , LAB_ORDER_DATE
FROM FG_WITHIN_TWO_YEARS
WHERE rn = 1;

--
-- TODO
-- I2B2 implementation where labs missing from PCORNET
--



---------------------------------------------------------------------------------------------------------------
-----     People with random glucose having two measures on different days within 2 years interval        -----
-----                                                                                                     -----
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 200 mg/dL.                                                                       -----
-----    (LOINC codes '2345-7', '2339-0','10450-5','17865-7','1554-5','6777-7','54246-4',                 -----
-----    '2344-0','41652-9')                                                                              -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'OBSERVATIONAL STAY', 'NON-ACUTE INSTITUTIONAL STAY'.                 -----
-----                                                                                                     -----
---------------------------------------------------------------------------------------------------------------
-----                                    May not be available in PCORNET                                  -----
---------------------------------------------------------------------------------------------------------------
-----    In this Oracle version of the code Patient age, encounter type and pregnancy masking is          -----
-----    accomplished by joining against the set of pregnancy masked eligible encounters                  -----
---------------------------------------------------------------------------------------------------------------

CREATE TABLE NextD_all_RG AS
WITH RG_LABS AS (
SELECT l.PATID
      ,l.LAB_ORDER_DATE
      ,l.LAB_NAME
      ,l.LAB_LOINC
      ,l.RESULT_NUM
      ,l.RESULT_UNIT
FROM "&&PCORNET_CDM".LAB_RESULT_CM l
WHERE l.LAB_LOINC IN ('2345-7', '2339-0','10450-5','17865-7','1554-5','6777-7','54246-4','2344-0','41652-9')
      AND l.RESULT_NUM >= 200
      AND UPPER(l.RESULT_UNIT) = 'MG/DL' -- PCORNET_CDM 3.1 standardizes on uppercase lab units
      AND EXISTS (SELECT 1 FROM NextD_preg_masked_encounters valid_encs
                           WHERE valid_encs.ENCOUNTERID = l.ENCOUNTERID)
)
SELECT * FROM RG_LABS
ORDER BY PATID, LAB_ORDER_DATE;

CREATE TABLE NextD_RG_final_FirstPair AS
WITH DELTA_RG AS (
SELECT PATID
      ,LAB_ORDER_DATE
      ,CASE WHEN LEAD(TRUNC(LAB_ORDER_DATE), 1, NULL) OVER (PARTITION BY PATID ORDER BY LAB_ORDER_DATE) - TRUNC(LAB_ORDER_DATE) BETWEEN 1 AND 365 * 2 
           THEN 1
           ELSE 0
       END AS WITHIN_TWO_YEARS
FROM NextD_all_RG
), RG_WITHIN_TWO_YEARS AS (
SELECT PATID
      ,LAB_ORDER_DATE
      ,row_number() OVER (PARTITION BY PATID ORDER BY LAB_ORDER_DATE) AS rn
FROM DELTA_RG
WHERE WITHIN_TWO_YEARS = 1
)
SELECT PATID
      , LAB_ORDER_DATE
FROM RG_WITHIN_TWO_YEARS
WHERE rn = 1;

--
-- TODO
-- I2B2 implementation where labs missing from PCORNET
--

---------------------------------------------------------------------------------------------------------------
-----     People with one random glucose & one HbA1c having both measures on different days within        -----
-----                                        2 years interval                                             -----
-----                                                                                                     -----
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    See corresponding sections above for the Lab values requerements.                                -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'OBSERVATIONAL STAY', 'NON-ACUTE INSTITUTIONAL STAY'.                 -----
-----                                                                                                     -----
-----        The date of the first lab out the first pair will be recorded as initial event.              -----
---------------------------------------------------------------------------------------------------------------

CREATE TABLE NextD_A1cRG_final_firstPair AS
WITH A1C_RG_PAIRS AS (
select  ac.PATID
       ,CASE WHEN rg.LAB_ORDER_DATE < ac.LAB_ORDER_DATE
             THEN rg.LAB_ORDER_DATE
             ELSE ac.LAB_ORDER_DATE
        END AS EventDate
       ,row_number() over (partition by ac.PATID order by CASE WHEN rg.LAB_ORDER_DATE < ac.LAB_ORDER_DATE
                                                               THEN rg.LAB_ORDER_DATE
                                                               ELSE ac.LAB_ORDER_DATE
                                                          END) AS rn
from NextD_all_A1C ac
join NextD_all_RG rg on ac.PATID = rg.PATID
WHERE ABS(TRUNC(ac.LAB_ORDER_DATE) - TRUNC(rg.LAB_ORDER_DATE)) BETWEEN 1 AND 365 * 2
)
SELECT PATID
      ,EventDate
FROM A1C_RG_PAIRS
WHERE rn = 1;


---------------------------------------------------------------------------------------------------------------
-----     People with one fasting glucose & one HbA1c having both measures on different days within       -----
-----                                        2 years interval                                             -----
-----                                                                                                     -----
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    See corresponding sections above for the Lab values requerements.                                -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'OBSERVATIONAL STAY', 'NON-ACUTE INSTITUTIONAL STAY'.                 -----
-----                                                                                                     -----
-----        The date of the first lab out the first pair will be recorded as initial event.              -----
---------------------------------------------------------------------------------------------------------------

CREATE TABLE NextD_A1cFG_final_firstPair AS
WITH A1C_FG_PAIRS AS (
select  ac.PATID
       ,CASE WHEN fg.LAB_ORDER_DATE < ac.LAB_ORDER_DATE
             THEN fg.LAB_ORDER_DATE
             ELSE ac.LAB_ORDER_DATE
        END AS EventDate
       ,row_number() over (partition by ac.PATID order by CASE WHEN fg.LAB_ORDER_DATE < ac.LAB_ORDER_DATE
                                                               THEN fg.LAB_ORDER_DATE
                                                               ELSE ac.LAB_ORDER_DATE
                                                          END) AS rn
from NextD_all_A1C ac
join NextD_all_FG fg on ac.PATID = fg.PATID
WHERE ABS(TRUNC(ac.LAB_ORDER_DATE) - TRUNC(fg.LAB_ORDER_DATE)) BETWEEN 1 AND 365 * 2
)
SELECT PATID
      ,EventDate
FROM A1C_FG_PAIRS
WHERE rn = 1;