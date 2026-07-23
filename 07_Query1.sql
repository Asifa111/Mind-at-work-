SET NOCOUNT ON;
GO

/*========================================================
Business Question

In 2024, how do smoking status and exercise status relate
to help-seeking and treatment behavior, and how does this
vary across different age groups and workplace comfort levels
for discussing mental health?

Uses:
- Fact_MentalHealthObservation
- Dim_Person
- Dim_DiscussingMentalHealthAtWork
- Dim_Date

Materialized View with Clustered Index
========================================================*/

/*========================================================
STEP 0: DROP INDEX IF EXISTS
========================================================*/
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_MV_Q_Obs_SmokingExerciseAgeComfort_2024'
      AND object_id = OBJECT_ID('dbo.MV_Q_Obs_SmokingExerciseAgeComfort_2024')
)
BEGIN
    DROP INDEX IX_MV_Q_Obs_SmokingExerciseAgeComfort_2024
    ON dbo.MV_Q_Obs_SmokingExerciseAgeComfort_2024;
END
GO

/*========================================================
STEP 1: DROP VIEW IF EXISTS
========================================================*/
IF OBJECT_ID('dbo.MV_Q_Obs_SmokingExerciseAgeComfort_2024', 'V') IS NOT NULL
    DROP VIEW dbo.MV_Q_Obs_SmokingExerciseAgeComfort_2024;
GO

/*========================================================
STEP 2: CREATE MATERIALIZED VIEW
========================================================*/
CREATE VIEW dbo.MV_Q_Obs_SmokingExerciseAgeComfort_2024
WITH SCHEMABINDING
AS
SELECT
    p.AgeGroup,
    dm.ComfortLevelCurrent,
    f.SmokingStatus,
    f.ExerciseStatus,

    COUNT_BIG(*) AS RecordCount,
    SUM(f.ObservationCount) AS TotalObservations,

    SUM(CASE 
            WHEN UPPER(LTRIM(RTRIM(ISNULL(f.SeekHelp, '')))) = 'YES' 
            THEN 1 ELSE 0 
        END) AS TotalSeekHelpYes,

    SUM(CASE 
            WHEN UPPER(LTRIM(RTRIM(ISNULL(f.Treatment, '')))) = 'YES' 
            THEN 1 ELSE 0 
        END) AS TotalTreatmentYes

FROM dbo.Fact_MentalHealthObservation AS f
INNER JOIN dbo.Dim_Person AS p
    ON f.PersonID = p.PersonID
INNER JOIN dbo.Dim_DiscussingMentalHealthAtWork AS dm
    ON f.DiscussingMentalHealthAtWorkID = dm.DiscussingMentalHealthAtWorkID
INNER JOIN dbo.Dim_Date AS d
    ON f.DateID = d.DateID

WHERE d.[Year] = 2024

GROUP BY
    p.AgeGroup,
    dm.ComfortLevelCurrent,
    f.SmokingStatus,
    f.ExerciseStatus;
GO

/*========================================================
STEP 3: CREATE UNIQUE CLUSTERED INDEX
========================================================*/
CREATE UNIQUE CLUSTERED INDEX IX_MV_Q_Obs_SmokingExerciseAgeComfort_2024
ON dbo.MV_Q_Obs_SmokingExerciseAgeComfort_2024
(
    AgeGroup,
    ComfortLevelCurrent,
    SmokingStatus,
    ExerciseStatus
);
GO

/*========================================================
STEP 4: DISPLAY QUERY
========================================================*/
SELECT
    AgeGroup,
    ComfortLevelCurrent,
    SmokingStatus,
    ExerciseStatus,
    TotalObservations,
    TotalSeekHelpYes,
    TotalTreatmentYes,

    CAST(
        CAST(TotalSeekHelpYes * 100.0 / NULLIF(TotalObservations, 0) AS DECIMAL(10,2))
        AS VARCHAR(20)
    ) + ' %' AS SeekHelpPercentage,

    CAST(
        CAST(TotalTreatmentYes * 100.0 / NULLIF(TotalObservations, 0) AS DECIMAL(10,2))
        AS VARCHAR(20)
    ) + ' %' AS TreatmentPercentage

FROM dbo.MV_Q_Obs_SmokingExerciseAgeComfort_2024
ORDER BY
    AgeGroup,
    ComfortLevelCurrent,
    SmokingStatus,
    ExerciseStatus;
GO