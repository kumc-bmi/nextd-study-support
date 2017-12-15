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

---------------------------------------------------------------------------------------------------------------
-----               People with two visits (inpatient, outpatient, or emergency department)               -----
-----             relevant to type 1 Diabetes Mellitus or type 2 Diabetes Mellitus diagnosis              -----
-----                        recorded on different days within 2 years interval                           -----
-----                                                                                                     -----
-----                         Visit should meet the following requerements:                               -----
-----    Patient must be 18 years old >= age <= 89 years old during on the visit day.                     -----
-----    Visit should should be of encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',           -----
-----    'INPATIENT HOSPITAL STAY', 'OBSERVATIONAL STAY', 'NON-ACUTE INSTITUTIONAL STAY'.                 -----
-----                                                                                                     -----
-----                  The first pair of visits meeting requerements is collected.                        -----
-----     The date of the first visit out the first pair will be recorded as initial event.               -----
---------------------------------------------------------------------------------------------------------------
-----    In this Oracle version of the code Patient age, encounter type and pregnancy masking is          -----
-----    accomplished by joining against the set of pregnancy masked eligible encounters                  -----
---------------------------------------------------------------------------------------------------------------
-- Get all visits of specified types for each patient sorted by date:

CREATE TABLE NextD_DX_Visits_initial AS
WITH DX_VISITS AS (
  SELECT d.PATID
        ,d.ADMIT_DATE
        ,d.DX
        ,d.DX_TYPE
  FROM "&&PCORNET_CDM".DIAGNOSIS d
  WHERE(
        (
         (
             d.DX LIKE '250.%'
          or d.DX LIKE '357.2'
          or regexp_like(d.DX,'^362.0[1-7]')
         )
         AND DX_TYPE = '09'
        )
        OR
        (
         (
             regexp_like(d.DX,'^E1[01]\.')
          or d.DX LIKE 'E08.42'
          or d.DX LIKE 'E13.42'
         )
         AND DX_TYPE = '10'
        )
       )
       AND EXISTS (SELECT 1 FROM NextD_preg_masked_encounters valid_encs
                   WHERE valid_encs.ENCOUNTERID = d.ENCOUNTERID)
)
SELECT * FROM DX_VISITS
ORDER BY PATID, ADMIT_DATE;

CREATE TABLE NextD_DX_Visit_final_FirstPair AS
WITH DELTA_DX AS (
SELECT PATID
      ,ADMIT_DATE
      ,CASE WHEN LEAD(TRUNC(ADMIT_DATE), 1, NULL) OVER (PARTITION BY PATID ORDER BY ADMIT_DATE) - TRUNC(ADMIT_DATE) BETWEEN 1 AND 365 * 2 
           THEN 1
           ELSE 0
       END AS WITHIN_TWO_YEARS
FROM NextD_DX_Visits_initial
), DX_WITHIN_TWO_YEARS AS (
SELECT PATID
      ,ADMIT_DATE
      ,row_number() OVER (PARTITION BY PATID ORDER BY ADMIT_DATE) AS rn
FROM DELTA_DX
WHERE WITHIN_TWO_YEARS = 1
)
SELECT PATID
      ,ADMIT_DATE
FROM DX_WITHIN_TWO_YEARS
WHERE rn = 1;


---------------------------------------------------------------------------------------------------------------
-----            People with at least one ordered medications specific to Diabetes Mellitus               -----
-----                                                                                                     -----            
-----                         Medication should meet the following requerements:                          -----
-----     Patient must be 18 years old >= age <= 89 years old during the ordering of medication           -----
-----    Medication should relate to encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',         -----
-----    'INPATIENT HOSPITAL STAY', 'OBSERVATIONAL STAY', 'NON-ACUTE INSTITUTIONAL STAY'.                 -----
-----                                                                                                     -----
-----                The date of the first medication meeting requerements is collected.                  -----
---------------------------------------------------------------------------------------------------------------
--  Sulfonylurea:
-- collect meds based on matching names:

CREATE TABLE NextD_specific_meds AS
SELECT a.PATID
      ,a.RX_ORDER_DATE
      ,a.RAW_RX_MED_NAME
      ,a.RXNORM_CUI
FROM "&&PCORNET_CDM".PRESCRIBING a 
WHERE EXISTS (SELECT 1 FROM NextD_preg_masked_encounters valid_encs
                       WHERE valid_encs.ENCOUNTERID = a.ENCOUNTERID) 
AND
(  
  -- Sufonylurea
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%Acetohexamide%') 
     or regexp_like(UPPER(a.RAW_RX_MED_NAME), UPPER('D[iy]melor')) 
     or regexp_like(UPPER(a.RAW_RX_MED_NAME), UPPER('glimep[ei]ride'))
     --This is combination of glimeperide-rosiglitazone :
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Avandaryl%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Amaryl%')
     --this is combination of glimepiride-pioglitazone:
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Duetact%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%gliclazide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Uni Diamicron%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%glipizide%')
     --this is combination of metformin-glipizide : 
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Metaglip%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glucotrol%')
     or regexp_like(UPPER(a.RAW_RX_MED_NAME),UPPER('Min[io]diab'))
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glibenese%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glucotrol XL%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glipizide XL%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%glyburide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glucovance%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%glibenclamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%DiaBeta%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glynase%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Micronase%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%chlorpropamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Diabinese%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Apo-Chlorpropamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glucamide%') 
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Novo-Propamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulase%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%tolazamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Tolinase%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glynase PresTab%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Tolamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%tolbutamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Orinase%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Tol-Tab%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Apo-Tolbutamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Novo-Butamide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glyclopyramide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Deamelin-S%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Gliquidone%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glurenorm%') 
     or a.RXNORM_CUI in (3842,153843,153844,153845,197306,197307,197495,197496,197737,198291,198292,198293,198294,199245,199246,199247,199825,201056,201057,201058,201059,201060,201061,201062,201063,201064,201919,201921,201922,203289,203295,203679,203680,203681,205828,205830,205872,205873,205875,205876,205879,205880,207953,207954,207955,208012,209204,214106,214107,217360,217364,217370,218942,220338,221173,224962,227211,241604,241605,245266,246391,246522,246523,246524,250919,252259,252960,260286,260287,261351,261974,284743,285129,310488,310489,310490,310534,310536,310537,310539,313418,313419,314000,314006,315107,315239,315273,315274,315647,315648,315978,315979,315980,315987,315988,315989,315990,315991,315992,316832,316833,316834,316835,316836,317379,317637,328851,330349,331496,332029,332808,332810,333394,336701,351452,352381,352764,353028,362611,367762,368204,368586,368696,368714,369297,369304,369373,369500,369557,369562,370529,371465,371466,371467,372318,372319,372320,372333,372334,374149,374152,374635,375952,376236,376868,378730,379559,379565,379568,379570,379572,379802,379803,379804,380849,389137,391828,393405,393406,405121,429841,430102,430103,430104,430105,432366,432780,432853,433856,438506,440285,440286,440287,465455,469978,542029,542030,542031,542032,563154,564035,564036,564037,564038,565327,565408,565409,565410,565667,565668,565669,565670,565671,565672,565673,565674,565675,566055,566056,566057,566718,566720,566761,566762,566764,566765,566768,566769,568684,568685,568686,568742,569831,573945,573946,574089,574090,574571,574612,575377,600423,600447,602543,602544,602549,602550,606253,607784,607816,647208,647235,647236,647237,647239,669981,669982,669983,669984,669985,669986,669987,687730,700835,706895,706896,731455,731457,731461,731462,731463,827400,844809,844824,844827,847706,847707,847708,847710,847712,847714,847716,847718,847720,847722,847724,849585,861731,861732,861733,861736,861737,861738,861740,861741,861742,861743,861745,861747,861748,861750,861752,861753,861755,861756,861757,865567,865568,865569,865570,865571,865572,865573,865574,881404,881405,881406,881407,881408,881409,881410,881411,1007411,1007582,1008873,1120401,1125922,1128359,1130921,1132391,1132805,1135219,1135428,1147918,1153126,1153127,1155467,1155468,1155469,1155470,1155471,1155472,1156197,1156198,1156199,1156200,1156201,1157121,1157122,1157240,1157241,1157242,1157243,1157244,1157245,1157246,1157247,1157642,1157643,1157644,1165203,1165204,1165205,1165206,1165207,1165208,1165845,1169680,1169681,1170663,1170664,1171233,1171234,1171246,1171247,1171248,1171249,1171933,1171934,1173427,1173428,1175658,1175659,1175878,1175879,1175880,1175881,1176496,1176497,1177973,1177974,1178082,1178083,1179112,1179113,1183952,1183954,1183958,1185049,1185624,1309022,1361492,1361493,1361494,1361495,1384487,1428269,1741234)
   )
OR
  --  Alpha-glucosidase inhibitor:
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%acarbose%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Precose%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glucobay%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%miglitol%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glyset%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Voglibose%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Basen%')
     or a.RXNORM_CUI in (16681,30009,137665,151826,199149,199150,200132,205329,205330,205331,209247,209248,213170,213485,213486,213487,217372,315246,315247,315248,316304,316305,316306,368246,368300,370504,372926,569871,569872,573095,573373,573374,573375,1153649,1153650,1157268,1157269,1171936,1171937,1185237,1185238,1598393,1741321)
   )
OR
  --Glucagon-like Peptide-1 Agonists:
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%Lixisenatide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Adlyxin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Lyxumia%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Albiglutide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Tanzeum%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Eperzan%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Dulaglutide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Trulicity%')
     or a.RXNORM_CUI in (1440051,1440052,1440053,1440056,1534763,1534797,1534798,1534800,1534801,1534802,1534804,1534805,1534806,1534807,1534819,1534820,1534821,1534822,1534823,1534824,1551291,1551292,1551293,1551295,1551296,1551297,1551299,1551300,1551301,1551302,1551303,1551304,1551305,1551306,1551307,1551308,1593645,1649584,1649586,1659115,1659117,1803885,1803886,1803887,1803888,1803889,1803890,1803891,1803892,1803893,1803894,1803895,1803896,1803897,1803898,1803902,1803903)
   )
OR   
  --  Dipeptidyl peptidase IV inhibitor:
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%alogliptin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Kazano%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Oseni%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Nesina%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Anagliptin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Suiny%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%linagliptin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Jentadueto%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Jentadueto XR%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glyxambi%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Tradjenta%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%saxagliptin%')
     --this is combination of metformin-saxagliptin :
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Kombiglyze XR%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Onglyza%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%sitagliptin%')
     --this is combination of metformin-vildagliptin :
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Eucreas%')
     --this is combination of sitagliptin-simvastatin:
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Juvisync%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Epistatin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Synvinolin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Zocor%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Janumet%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Janumet XR%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Januvia%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Teneligliptin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Tenelia%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Vildagliptin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Galvus%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Zomelis%')
     or a.RXNORM_CUI in (36567,104490,104491,152923,196503,208220,213319,368276,563653,563654,565109,568935,573220,593411,596554,621590,638596,665031,665032,665033,665034,665035,665036,665037,665038,665039,665040,665041,665042,665043,665044,669475,700516,729717,757603,757708,757709,757710,757711,757712,857974,858034,858035,858036,858037,858038,858039,858040,858041,858042,858043,858044,861769,861770,861771,861819,861820,861821,1043560,1043561,1043562,1043563,1043565,1043566,1043567,1043568,1043569,1043570,1043572,1043574,1043575,1043576,1043578,1043580,1043582,1043583,1043584,1048346,1100699,1100700,1100701,1100702,1100703,1100704,1100705,1100706,1128666,1130631,1132606,1145961,1158518,1158519,1159662,1159663,1161605,1161606,1161607,1161608,1164580,1164581,1164670,1164671,1167810,1167811,1167814,1167815,1179163,1179164,1181729,1181730,1187973,1187974,1189800,1189801,1189802,1189803,1189804,1189806,1189808,1189810,1189811,1189812,1189813,1189814,1189818,1189821,1189823,1189827,1243015,1243016,1243017,1243018,1243019,1243020,1243022,1243026,1243027,1243029,1243033,1243034,1243036,1243037,1243038,1243039,1243040,1243826,1243827,1243829,1243833,1243834,1243835,1243839,1243842,1243843,1243844,1243845,1243846,1243848,1243849,1243850,1312409,1312411,1312415,1312416,1312418,1312422,1312423,1312425,1312429,1365802,1368000,1368001,1368002,1368003,1368004,1368005,1368006,1368007,1368008,1368009,1368010,1368011,1368012,1368017,1368018,1368019,1368020,1368033,1368034,1368035,1368036,1368381,1368382,1368383,1368384,1368385,1368387,1368391,1368392,1368394,1368395,1368396,1368397,1368398,1368399,1368400,1368401,1368402,1368403,1368405,1368409,1368410,1368412,1368416,1368417,1368419,1368423,1368424,1368426,1368430,1368431,1368433,1368434,1368435,1368436,1368437,1368438,1368440,1368444,1372692,1372706,1372717,1372738,1372754,1431025,1431048,1546030,1598392,1602106,1602107,1602108,1602109,1602110,1602111,1602112,1602113,1602114,1602115,1602118,1602119,1602120,1692194,1727500,1741248,1741249,1791055,1796088,1796089,1796090,1796091,1796092,1796093,1796094,1796095,1796096,1796097,1796098,1803420)
   )
OR
  -- Meglitinide:
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%nateglinide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Starlix%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Prandin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%NovoNorm%')
     or a.RXNORM_CUI in (213218,213219,213220,219335,226911,226912,226913,226914,274332,284529,284530,311919,314142,330385,330386,368289,374648,389139,393408,402943,402944,402959,430491,430492,446631,446632,573136,573137,573138,574042,574043,574044,574957,574958,1158396,1158397,1178121,1178122,1178433,1178434,1184631,1184632)
   )
OR
  --  Amylinomimetics:
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%Pramlintide%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Symlin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%SymlinPen 120%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%SymlinPen 60%')
     or a.RXNORM_CUI in (139953,356773,356774,486505,582702,607296,753370,753371,759000,861034,861036,861038,861039,861040,861041,861042,861043,861044,861045,1161690,1185508,1360096,1360184,1657563,1657565,1657792)
   )
OR
  --  Insulin:
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin aspart%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%NovoLog%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin glulisine%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Apidra%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin lispro%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Humalog%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin inhaled%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Afrezza%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Regular insulin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Humulin R%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Novolin R%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin NPH%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Humulin N%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Novolin N%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin detemir%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Levemir%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin glargine%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Lantus%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Lantus SoloStar%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Toujeo%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Basaglar%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin degludec%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Tresiba%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin aspart protamine%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin aspart%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Actrapid%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Hypurin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Iletin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulatard%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insuman%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Mixtard%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%NovoMix%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%NovoRapid%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Oralin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Abasaglar%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%V-go%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Ryzodeg%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Insulin lispro protamine%')
     or a.RXNORM_CUI in (5856,6926,51428,86009,92880,92881,92942,93398,93558,93560,106888,106889,106891,106892,106894,106895,106896,106899,106900,106901,108407,108813,108814,108815,108816,108822,135805,139825,142138,150659,150831,150973,150974,150978,152598,152599,152602,152640,152644,152647,153383,153384,153386,153389,154992,203209,213442,217704,217705,217706,217707,217708,225569,226290,226291,226292,226293,226294,242120,245264,245265,247511,247512,247513,249026,249220,253181,253182,259111,260265,261111,261112,261420,261542,261551,274783,284810,285018,307383,311021,311026,311027,311028,311030,311033,311034,311035,311036,311040,311041,311048,311049,311051,311052,311059,314684,340325,340326,340327,343076,343083,343226,343258,343263,343663,349670,351297,351857,351858,351859,351860,351861,351862,351926,352385,352386,359125,359126,359127,360894,362585,362622,362777,363120,363150,363221,363534,365573,365583,365668,365670,365672,365674,365677,365679,365680,366206,372909,372910,375170,376915,378841,378857,378864,378966,379734,379740,379744,379745,379746,379747,379750,379756,379757,384982,385896,386083,386084,386086,386087,386088,386089,386091,386092,386098,388513,392660,400008,400560,405228,412453,412978,415088,415089,415090,415184,415185,440399,440650,440653,440654,451437,451439,466467,466468,467015,484320,484321,484322,485210,564390,564391,564392,564395,564396,564397,564399,564400,564401,564531,564601,564602,564603,564605,564766,564820,564881,564882,564885,564994,564995,564998,565176,565253,565254,565255,565256,573330,573331,574358,574359,575068,575137,575141,575142,575143,575146,575147,575148,575151,575626,575627,575628,575629,575679,607583,615900,615908,615909,615910,615992,616236,616237,616238,633703,636227,658226,668934,723550,724231,724343,727907,728543,731277,731280,731281,752386,752388,761522,796006,796386,801808,803192,803193,803194,816726,834989,834990,834992,835225,835226,835227,835228,835868,847186,847187,847188,847189,847191,847194,847198,847199,847200,847201,847202,847203,847204,847205,847211,847213,847230,847232,847239,847241,847252,847254,847256,847257,847259,847261,847278,847279,847343,847417,849095,865097,865098,977838,977840,977841,977842,1008501,1045051,1069670,1087799,1087800,1087801,1087802,1132383,1136628,1136712,1140739,1140763,1157459,1157460,1157461,1160696,1164093,1164094,1164095,1164824,1167138,1167139,1167140,1167141,1167142,1167934,1168563,1171289,1171291,1171292,1171293,1171295,1171296,1172691,1172692,1175624,1176722,1176723,1176724,1176725,1176726,1176727,1176728,1177009,1178119,1178120,1178127,1178128,1183426,1183427,1184075,1184076,1184077,1246223,1246224,1246225,1246697,1246698,1246699,1260529,1295992,1296093,1309028,1359484,1359581,1359684,1359700,1359712,1359719,1359720,1359855,1359856,1359934,1359936,1360036,1360058,1360172,1360226,1360281,1360383,1360435,1360482,1362705,1362706,1362707,1362708,1362711,1362712,1362713,1362714,1362719,1362720,1362721,1362722,1362723,1362724,1362725,1362726,1362727,1362728,1362729,1362730,1362731,1362732,1372685,1372741,1374700,1374701,1377831,1435649,1456746,1535271,1538910,1543200,1543201,1543202,1543203,1543205,1543206,1543207,1544488,1544490,1544568,1544569,1544570,1544571,1593805,1598498,1598618,1604538,1604539,1604540,1604541,1604543,1604544,1604545,1604546,1604550,1605101,1607367,1607643,1607992,1607993,1650256,1650260,1650262,1650264,1651315,1651572,1651574,1652237,1652238,1652239,1652240,1652241,1652242,1652243,1652244,1652639,1652640,1652641,1652642,1652643,1652644,1652645,1652646,1652647,1652648,1652754,1653104,1653106,1653196,1653197,1653198,1653200,1653202,1653203,1653204,1653206,1653209,1653449,1653468,1653496,1653497,1653499,1653506,1653899,1654060,1654190,1654192,1654341,1654348,1654379,1654380,1654381,1654651,1654850,1654855,1654857,1654858,1654862,1654863,1654866,1654909,1654910,1654911,1654912,1655063,1656705,1656706,1660643,1663228,1663229,1664772,1665830,1668430,1668441,1668442,1668448,1670007,1670008,1670009,1670010,1670011,1670012,1670013,1670014,1670015,1670016,1670017,1670018,1670020,1670021,1670022,1670023,1670024,1670025,1670404,1670405,1716525,1717038,1717039,1719496,1720524,1721033,1721039,1727493,1731314,1731315,1731316,1731317,1731318,1731319,1736613,1736859,1736860,1736861,1736862,1736863,1736864,1743273,1792701,1798387,1798388,1804446,1804447,1804505,1804506)

   )
OR
  --  Sodium glucose cotransporter (SGLT) 2 inhibitors:
   (
        UPPER(a.RAW_RX_MED_NAME) like UPPER('%dapagliflozin%')
     or regexp_like(UPPER(a.RAW_RX_MED_NAME), UPPER('F[ao]rxiga'))
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%canagliflozin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Invokana%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Invokamet%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Xigduo XR%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Sulisent%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%empagliflozin%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Jardiance%')
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Synjardy%')
     --this one is combination of linagliptin-empagliflozin, see also Dipeptidyl Peptidase IV Inhibitors section
     or UPPER(a.RAW_RX_MED_NAME) like UPPER('%Glyxambi%')
     or a.RXNORM_CUI in (1373458,1373459,1373460,1373461,1373462,1373463,1373464,1373465,1373466,1373467,1373468,1373469,1373470,1373471,1373472,1373473,1422532,1486436,1486966,1486977,1486981,1488564,1488565,1488566,1488567,1488568,1488569,1488573,1488574,1493571,1493572,1534343,1534344,1534397,1540290,1540292,1545145,1545146,1545147,1545148,1545149,1545150,1545151,1545152,1545153,1545154,1545155,1545156,1545157,1545158,1545159,1545160,1545161,1545162,1545163,1545164,1545165,1545166,1545653,1545654,1545655,1545656,1545657,1545658,1545659,1545660,1545661,1545662,1545663,1545664,1545665,1545666,1545667,1545668,1546031,1592709,1592710,1592722,1593057,1593058,1593059,1593068,1593069,1593070,1593071,1593072,1593073,1593774,1593775,1593776,1593826,1593827,1593828,1593829,1593830,1593831,1593832,1593833,1593835,1598392,1598430,1602106,1602107,1602108,1602109,1602110,1602111,1602112,1602113,1602114,1602115,1602118,1602119,1602120,1655477,1664310,1664311,1664312,1664313,1664314,1664315,1664316,1664317,1664318,1664319,1664320,1664321,1664322,1664323,1664324,1664325,1664326,1664327,1664328,1665367,1665368,1665369,1683935,1727500)
   )
);
