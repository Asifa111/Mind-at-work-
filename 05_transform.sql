SET NOCOUNT ON;
GO

/*========================================================
05_transform.sql
Purpose:
- Combine the three staging tables into one cleaned
  transformed table
- Standardize raw values into one common structure
- Remove exact duplicates inside the current load
- Insert only new rows into dbo.MentalHealth_Transformed

Important:
- This script uses RowHash-based delta loading
- If the same rows already exist in dbo.MentalHealth_Transformed,
  the insert count will be 0 by design
- Uncomment TRUNCATE only when you want a full reload
========================================================*/

PRINT 'Starting 05_transform.sql ...';
GO

/*========================================================
OPTIONAL FULL RELOAD
Use only if you want to rebuild the transformed table
from scratch instead of delta loading.
========================================================*/
TRUNCATE TABLE dbo.MentalHealth_Transformed;
GO

/*========================================================
STEP 1: DROP TEMP CANDIDATE TABLE IF EXISTS
========================================================*/
IF OBJECT_ID('tempdb..#Transformed_Candidate', 'U') IS NOT NULL
    DROP TABLE #Transformed_Candidate;
GO

/*========================================================
STEP 2: CREATE TEMP CANDIDATE TABLE
Purpose:
- Hold rows from all source systems in one common format
- Prepare data before duplicate removal and delta insert
========================================================*/
CREATE TABLE #Transformed_Candidate
(
    SourceSystem VARCHAR(50) NULL,
    SourcePersonID INT NULL,
    FullDate DATE NULL,

    Gender VARCHAR(50) NULL,
    AgeGroup VARCHAR(100) NULL,
    Education VARCHAR(150) NULL,
    IncomeLevel VARCHAR(150) NULL,
    FamilyHistory VARCHAR(50) NULL,

    Country VARCHAR(100) NULL,
    State VARCHAR(100) NULL,

    WorkInterference VARCHAR(50) NULL,
    RemoteWork VARCHAR(50) NULL,
    Benefits VARCHAR(50) NULL,

    GeneralHealthStatus VARCHAR(100) NULL,
    MentalHealthDays INT NULL,
    CheckUpStatus VARCHAR(100) NULL,
    SmokingStatus VARCHAR(50) NULL,
    ExerciseStatus VARCHAR(50) NULL,

    SeekHelp VARCHAR(50) NULL,
    Treatment VARCHAR(50) NULL,

    NumEmployees VARCHAR(50) NULL,
    TechCompany VARCHAR(50) NULL,
    CareOptions VARCHAR(50) NULL,
    WellnessProgram VARCHAR(50) NULL,

    AwarenessLevel VARCHAR(50) NULL,
    KnowledgeLevel VARCHAR(50) NULL,
    ComfortLevel VARCHAR(50) NULL,
    ManagerSupport VARCHAR(50) NULL,

    RowHash VARBINARY(32) NULL
);
GO

/*========================================================
STEP 3: LOAD FROM dbo.MentalHealth_Staging
Notes:
- This source mainly contributes demographic, health,
  lifestyle, checkup, and state data
- Country is fixed to United States for this source
- Workplace-related attributes are not available here,
  so they are defaulted to Not Found
========================================================*/
INSERT INTO #Transformed_Candidate
(
    SourceSystem,
    SourcePersonID,
    FullDate,
    Gender,
    AgeGroup,
    Education,
    IncomeLevel,
    FamilyHistory,
    Country,
    State,
    WorkInterference,
    RemoteWork,
    Benefits,
    GeneralHealthStatus,
    MentalHealthDays,
    CheckUpStatus,
    SmokingStatus,
    ExerciseStatus,
    SeekHelp,
    Treatment,
    NumEmployees,
    TechCompany,
    CareOptions,
    WellnessProgram,
    AwarenessLevel,
    KnowledgeLevel,
    ComfortLevel,
    ManagerSupport,
    RowHash
)
SELECT
    'MentalHealth_Staging' AS SourceSystem,
    NULL AS SourcePersonID,
    TRY_CONVERT
    (
        DATE,
        STUFF
        (
            STUFF(RIGHT('00000000' + CAST(s.[Date] AS VARCHAR(20)), 8), 3, 0, '/'),
            6, 0, '/'
        )
    ) AS FullDate,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Gender AS VARCHAR(50)))), ''), 'Not Found') AS Gender,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.AgeGroup AS VARCHAR(100)))), ''), 'Not Found') AS AgeGroup,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Education AS VARCHAR(150)))), ''), 'Not Found') AS Education,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.IncomeLevel AS VARCHAR(150)))), ''), 'Not Found') AS IncomeLevel,
    'Not Found' AS FamilyHistory,
    'United States' AS Country,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.State AS VARCHAR(100)))), ''), 'Not Found') AS State,
    'Not Found' AS WorkInterference,
    'Not Found' AS RemoteWork,
    'Not Found' AS Benefits,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.GeneralHealthStatus AS VARCHAR(100)))), ''), 'Not Found') AS GeneralHealthStatus,
    CASE
        WHEN TRY_CONVERT(INT, s.MentalHealthDays) BETWEEN 0 AND 30
            THEN TRY_CONVERT(INT, s.MentalHealthDays)
        ELSE NULL
    END AS MentalHealthDays,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.CheckUpStatus AS VARCHAR(100)))), ''), 'Not Found') AS CheckUpStatus,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SmokingStatus AS VARCHAR(50)))), ''), 'Not Found') AS SmokingStatus,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ExerciseStatus AS VARCHAR(50)))), ''), 'Not Found') AS ExerciseStatus,
    'Not Found' AS SeekHelp,
    'Not Found' AS Treatment,
    'Not Found' AS NumEmployees,
    'Not Found' AS TechCompany,
    'Not Found' AS CareOptions,
    'Not Found' AS WellnessProgram,
    'Not Found' AS AwarenessLevel,
    'Not Found' AS KnowledgeLevel,
    'Not Found' AS ComfortLevel,
    'Not Found' AS ManagerSupport,
    HASHBYTES
    (
        'SHA2_256',
        CONCAT
        (
            'MentalHealth_Staging','|',
            COALESCE(CONVERT(VARCHAR(10),
                TRY_CONVERT
                (
                    DATE,
                    STUFF
                    (
                        STUFF(RIGHT('00000000' + CAST(s.[Date] AS VARCHAR(20)), 8), 3, 0, '/'),
                        6, 0, '/'
                    )
                ),
            120),'')
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Gender AS VARCHAR(50)))), ''), 'Not Found')
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.AgeGroup AS VARCHAR(100)))), ''), 'Not Found')
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Education AS VARCHAR(150)))), ''), 'Not Found')
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.IncomeLevel AS VARCHAR(150)))), ''), 'Not Found')
            ,'|', 'Not Found'
            ,'|', 'United States'
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.State AS VARCHAR(100)))), ''), 'Not Found')
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.GeneralHealthStatus AS VARCHAR(100)))), ''), 'Not Found')
            ,'|', COALESCE(CAST(
                    CASE
                        WHEN TRY_CONVERT(INT, s.MentalHealthDays) BETWEEN 0 AND 30
                            THEN TRY_CONVERT(INT, s.MentalHealthDays)
                        ELSE NULL
                    END AS VARCHAR(20)), '')
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.CheckUpStatus AS VARCHAR(100)))), ''), 'Not Found')
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SmokingStatus AS VARCHAR(50)))), ''), 'Not Found')
            ,'|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ExerciseStatus AS VARCHAR(50)))), ''), 'Not Found')
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
            ,'|', 'Not Found'
        )
    ) AS RowHash
FROM dbo.MentalHealth_Staging s;
GO

/*========================================================
STEP 4: LOAD FROM dbo.MentalHealthWorkPlace_Staging
Notes:
- This source mainly contributes workplace and support data
- FullDate is not available here
- Education, income, and health-day columns are defaulted
  because they do not exist in this source
========================================================*/
INSERT INTO #Transformed_Candidate
(
    SourceSystem,
    SourcePersonID,
    FullDate,
    Gender,
    AgeGroup,
    Education,
    IncomeLevel,
    FamilyHistory,
    Country,
    State,
    WorkInterference,
    RemoteWork,
    Benefits,
    GeneralHealthStatus,
    MentalHealthDays,
    CheckUpStatus,
    SmokingStatus,
    ExerciseStatus,
    SeekHelp,
    Treatment,
    NumEmployees,
    TechCompany,
    CareOptions,
    WellnessProgram,
    AwarenessLevel,
    KnowledgeLevel,
    ComfortLevel,
    ManagerSupport,
    RowHash
)
SELECT
    'MentalHealthWorkPlace_Staging' AS SourceSystem,
    NULL AS SourcePersonID,
    NULL AS FullDate,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Gender AS VARCHAR(50)))), ''), 'Not Found') AS Gender,
    CASE
        WHEN TRY_CONVERT(INT, s.Age) BETWEEN 18 AND 24 THEN '18-24'
        WHEN TRY_CONVERT(INT, s.Age) BETWEEN 25 AND 34 THEN '25-34'
        WHEN TRY_CONVERT(INT, s.Age) BETWEEN 35 AND 44 THEN '35-44'
        WHEN TRY_CONVERT(INT, s.Age) BETWEEN 45 AND 54 THEN '45-54'
        WHEN TRY_CONVERT(INT, s.Age) BETWEEN 55 AND 64 THEN '55-64'
        WHEN TRY_CONVERT(INT, s.Age) >= 65 THEN '65+'
        ELSE 'Not Found'
    END AS AgeGroup,
    'Not Found' AS Education,
    'Not Found' AS IncomeLevel,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.FamilyHistory AS VARCHAR(50)))), ''), 'Not Found') AS FamilyHistory,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Country AS VARCHAR(100)))), ''), 'Not Found') AS Country,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.State AS VARCHAR(100)))), ''), 'Not Found') AS State,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WorkInterference AS VARCHAR(50)))), ''), 'Not Found') AS WorkInterference,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.RemoteWork AS VARCHAR(50)))), ''), 'Not Found') AS RemoteWork,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Benefits AS VARCHAR(50)))), ''), 'Not Found') AS Benefits,
    'Not Found' AS GeneralHealthStatus,
    NULL AS MentalHealthDays,
    'Not Found' AS CheckUpStatus,
    'Not Found' AS SmokingStatus,
    'Not Found' AS ExerciseStatus,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SeekHelp AS VARCHAR(50)))), ''), 'Not Found') AS SeekHelp,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Treatment AS VARCHAR(50)))), ''), 'Not Found') AS Treatment,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.NumEmployees AS VARCHAR(50)))), ''), 'Not Found') AS NumEmployees,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.TechCompany AS VARCHAR(50)))), ''), 'Not Found') AS TechCompany,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.CareOptions AS VARCHAR(50)))), ''), 'Not Found') AS CareOptions,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WellnessProgram AS VARCHAR(50)))), ''), 'Not Found') AS WellnessProgram,
    'Not Found' AS AwarenessLevel,
    'Not Found' AS KnowledgeLevel,
    'Not Found' AS ComfortLevel,
    'Not Found' AS ManagerSupport,
    HASHBYTES
    (
        'SHA2_256',
        CONCAT
        (
            'MentalHealthWorkPlace_Staging','|',
            '',
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Gender AS VARCHAR(50)))), ''), 'Not Found'),
            '|', CASE
                    WHEN TRY_CONVERT(INT, s.Age) BETWEEN 18 AND 24 THEN '18-24'
                    WHEN TRY_CONVERT(INT, s.Age) BETWEEN 25 AND 34 THEN '25-34'
                    WHEN TRY_CONVERT(INT, s.Age) BETWEEN 35 AND 44 THEN '35-44'
                    WHEN TRY_CONVERT(INT, s.Age) BETWEEN 45 AND 54 THEN '45-54'
                    WHEN TRY_CONVERT(INT, s.Age) BETWEEN 55 AND 64 THEN '55-64'
                    WHEN TRY_CONVERT(INT, s.Age) >= 65 THEN '65+'
                    ELSE 'Not Found'
               END,
            '|', 'Not Found',
            '|', 'Not Found',
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.FamilyHistory AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Country AS VARCHAR(100)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.State AS VARCHAR(100)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WorkInterference AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.RemoteWork AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Benefits AS VARCHAR(50)))), ''), 'Not Found'),
            '|', 'Not Found',
            '|', '',
            '|', 'Not Found',
            '|', 'Not Found',
            '|', 'Not Found',
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SeekHelp AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Treatment AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.NumEmployees AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.TechCompany AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.CareOptions AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WellnessProgram AS VARCHAR(50)))), ''), 'Not Found'),
            '|', 'Not Found',
            '|', 'Not Found',
            '|', 'Not Found',
            '|', 'Not Found'
        )
    ) AS RowHash
FROM dbo.MentalHealthWorkPlace_Staging s;
GO

/*========================================================
STEP 5: LOAD FROM dbo.AI_Staging
Notes:
- This source contributes the most complete combined record
- FullDate comes directly from AI_Staging
========================================================*/
INSERT INTO #Transformed_Candidate
(
    SourceSystem,
    SourcePersonID,
    FullDate,
    Gender,
    AgeGroup,
    Education,
    IncomeLevel,
    FamilyHistory,
    Country,
    State,
    WorkInterference,
    RemoteWork,
    Benefits,
    GeneralHealthStatus,
    MentalHealthDays,
    CheckUpStatus,
    SmokingStatus,
    ExerciseStatus,
    SeekHelp,
    Treatment,
    NumEmployees,
    TechCompany,
    CareOptions,
    WellnessProgram,
    AwarenessLevel,
    KnowledgeLevel,
    ComfortLevel,
    ManagerSupport,
    RowHash
)
SELECT
    'AI_Staging' AS SourceSystem,
    s.SourcePersonID,
    s.FullDate,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Gender AS VARCHAR(50)))), ''), 'Not Found') AS Gender,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.AgeGroup AS VARCHAR(100)))), ''), 'Not Found') AS AgeGroup,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Education AS VARCHAR(150)))), ''), 'Not Found') AS Education,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.IncomeLevel AS VARCHAR(150)))), ''), 'Not Found') AS IncomeLevel,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.FamilyHistory AS VARCHAR(50)))), ''), 'Not Found') AS FamilyHistory,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Country AS VARCHAR(100)))), ''), 'Not Found') AS Country,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.State AS VARCHAR(100)))), ''), 'Not Found') AS State,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WorkInterference AS VARCHAR(50)))), ''), 'Not Found') AS WorkInterference,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.RemoteWork AS VARCHAR(50)))), ''), 'Not Found') AS RemoteWork,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Benefits AS VARCHAR(50)))), ''), 'Not Found') AS Benefits,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.GeneralHealthStatus AS VARCHAR(100)))), ''), 'Not Found') AS GeneralHealthStatus,
    CASE
        WHEN TRY_CONVERT(INT, s.MentalHealthDays) BETWEEN 0 AND 30
            THEN TRY_CONVERT(INT, s.MentalHealthDays)
        ELSE NULL
    END AS MentalHealthDays,
    'Not Found' AS CheckUpStatus,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SmokingStatus AS VARCHAR(50)))), ''), 'Not Found') AS SmokingStatus,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ExerciseStatus AS VARCHAR(50)))), ''), 'Not Found') AS ExerciseStatus,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SeekHelp AS VARCHAR(50)))), ''), 'Not Found') AS SeekHelp,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Treatment AS VARCHAR(50)))), ''), 'Not Found') AS Treatment,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.NumEmployees AS VARCHAR(50)))), ''), 'Not Found') AS NumEmployees,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.TechCompany AS VARCHAR(50)))), ''), 'Not Found') AS TechCompany,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.CareOptions AS VARCHAR(50)))), ''), 'Not Found') AS CareOptions,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WellnessProgram AS VARCHAR(50)))), ''), 'Not Found') AS WellnessProgram,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.AwarenessLevel AS VARCHAR(50)))), ''), 'Not Found') AS AwarenessLevel,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.KnowledgeLevel AS VARCHAR(50)))), ''), 'Not Found') AS KnowledgeLevel,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ComfortLevel AS VARCHAR(50)))), ''), 'Not Found') AS ComfortLevel,
    COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ManagerSupport AS VARCHAR(50)))), ''), 'Not Found') AS ManagerSupport,
    HASHBYTES
    (
        'SHA2_256',
        CONCAT
        (
            'AI_Staging','|',
            COALESCE(CAST(s.SourcePersonID AS VARCHAR(20)), ''),
            '|', COALESCE(CONVERT(VARCHAR(10), s.FullDate, 120), ''),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Gender AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.AgeGroup AS VARCHAR(100)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Education AS VARCHAR(150)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.IncomeLevel AS VARCHAR(150)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.FamilyHistory AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Country AS VARCHAR(100)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.State AS VARCHAR(100)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WorkInterference AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.RemoteWork AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Benefits AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.GeneralHealthStatus AS VARCHAR(100)))), ''), 'Not Found'),
            '|', COALESCE(CAST(
                    CASE
                        WHEN TRY_CONVERT(INT, s.MentalHealthDays) BETWEEN 0 AND 30
                            THEN TRY_CONVERT(INT, s.MentalHealthDays)
                        ELSE NULL
                    END AS VARCHAR(20)), ''),
            '|', 'Not Found',
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SmokingStatus AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ExerciseStatus AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.SeekHelp AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.Treatment AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.NumEmployees AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.TechCompany AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.CareOptions AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.WellnessProgram AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.AwarenessLevel AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.KnowledgeLevel AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ComfortLevel AS VARCHAR(50)))), ''), 'Not Found'),
            '|', COALESCE(NULLIF(LTRIM(RTRIM(CAST(s.ManagerSupport AS VARCHAR(50)))), ''), 'Not Found')
        )
    ) AS RowHash
FROM dbo.AI_Staging s;
GO

/*========================================================
STEP 6: REMOVE EXACT DUPLICATES INSIDE CANDIDATE
========================================================*/
;WITH Dedup AS
(
    SELECT *,
           ROW_NUMBER() OVER
           (
               PARTITION BY RowHash
               ORDER BY SourceSystem, SourcePersonID, FullDate
           ) AS rn
    FROM #Transformed_Candidate
)
DELETE FROM Dedup
WHERE rn > 1;
GO

/*========================================================
STEP 7: SHOW DELTA COUNTS
========================================================*/
SELECT COUNT(*) AS Candidate_Row_Count
FROM #Transformed_Candidate;
GO

SELECT COUNT(*) AS NewRowsToInsert
FROM #Transformed_Candidate c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.MentalHealth_Transformed t
    WHERE t.RowHash = c.RowHash
);
GO

/*========================================================
STEP 8: INSERT ONLY NEW ROWS INTO TRANSFORMED TABLE
========================================================*/
INSERT INTO dbo.MentalHealth_Transformed
(
    SourceSystem,
    SourcePersonID,
    FullDate,
    Gender,
    AgeGroup,
    Education,
    IncomeLevel,
    FamilyHistory,
    Country,
    State,
    NumEmployees,
    TechCompany,
    CareOptions,
    WellnessProgram,
    RemoteWork,
    Benefits,
    AwarenessLevel,
    KnowledgeLevel,
    ComfortLevel,
    ManagerSupport,
    WorkInterference,
    SeekHelp,
    SmokingStatus,
    ExerciseStatus,
    Treatment,
    GeneralHealthStatus,
    MentalHealthDays,
    CheckUpStatus,
    RowHash,
    LoadTimestamp
)
SELECT
    c.SourceSystem,
    c.SourcePersonID,
    c.FullDate,
    c.Gender,
    c.AgeGroup,
    c.Education,
    c.IncomeLevel,
    c.FamilyHistory,
    c.Country,
    c.State,
    c.NumEmployees,
    c.TechCompany,
    c.CareOptions,
    c.WellnessProgram,
    c.RemoteWork,
    c.Benefits,
    c.AwarenessLevel,
    c.KnowledgeLevel,
    c.ComfortLevel,
    c.ManagerSupport,
    c.WorkInterference,
    c.SeekHelp,
    c.SmokingStatus,
    c.ExerciseStatus,
    c.Treatment,
    c.GeneralHealthStatus,
    c.MentalHealthDays,
    c.CheckUpStatus,
    c.RowHash,
    SYSDATETIME()
FROM #Transformed_Candidate c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.MentalHealth_Transformed t
    WHERE t.RowHash = c.RowHash
);
GO

/*========================================================
STEP 9: FINAL VALIDATION
========================================================*/
SELECT COUNT(*) AS Final_Transformed_Row_Count
FROM dbo.MentalHealth_Transformed;
GO

SELECT SourceSystem, COUNT(*) AS TotalRows
FROM dbo.MentalHealth_Transformed
GROUP BY SourceSystem
ORDER BY SourceSystem;
GO

PRINT '05_transform.sql completed successfully.';
GO


----
SELECT TOP 5 * FROM dbo.MentalHealth_Staging;
SELECT TOP 5 * FROM dbo.MentalHealthWorkPlace_Staging;
SELECT TOP 5 * FROM dbo.AI_Staging;