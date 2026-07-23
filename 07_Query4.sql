SET NOCOUNT ON;
GO

/*========================================================
Business Question

In 2024, how does employees' education level relate to
their likelihood of seeking help and receiving treatment,
and how does this vary across different workplace mental
health comfort levels?

Uses:
- Fact_MentalHealthObservation
- Dim_Person
- Dim_DiscussingMentalHealthAtWork
- Dim_Date
========================================================*/

IF OBJECT_ID('dbo.VW_Education_Comfort_SeekHelp_Treatment_2024', 'V') IS NOT NULL
    DROP VIEW dbo.VW_Education_Comfort_SeekHelp_Treatment_2024;
GO

CREATE VIEW dbo.VW_Education_Comfort_SeekHelp_Treatment_2024
AS
SELECT
    d.[Year],
    p.Education,
    dm.ComfortLevelCurrent AS ComfortLevel,

    COUNT(*) AS TotalObservations,

    SUM(
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(f.SeekHelp, '')))) = 'YES' THEN 1
            ELSE 0
        END
    ) AS TotalSeekHelpYes,

    SUM(
        CASE
             WHEN UPPER(LTRIM(RTRIM(ISNULL(f.Treatment, '')))) = 'YES' THEN 1
            ELSE 0
        END
    ) AS TotalTreatmentYes,

    CAST(
        CAST(
            SUM(
                CASE
                    WHEN UPPER(LTRIM(RTRIM(ISNULL(f.SeekHelp, '')))) = 'YES' THEN 1
                    ELSE 0
                END
            ) * 100.0 / NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS VARCHAR(20)
    ) + ' %' AS SeekHelpPercentage,

    CAST(
        CAST(
            SUM(
                CASE
                    WHEN UPPER(LTRIM(RTRIM(ISNULL(f.Treatment, '')))) = 'YES' THEN 1
                    ELSE 0
                END
            ) * 100.0 / NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS VARCHAR(20)
    ) + ' %' AS TreatmentPercentage

FROM dbo.Fact_MentalHealthObservation f
INNER JOIN dbo.Dim_Person p
    ON f.PersonID = p.PersonID
INNER JOIN dbo.Dim_DiscussingMentalHealthAtWork dm
    ON f.DiscussingMentalHealthAtWorkID = dm.DiscussingMentalHealthAtWorkID
INNER JOIN dbo.Dim_Date d
    ON f.DateID = d.DateID

WHERE d.[Year] = 2024

GROUP BY
    d.[Year],
    p.Education,
    dm.ComfortLevelCurrent;
GO
/*========================================================
DISPLAY RESULT FROM VIEW
========================================================*/

SELECT *
FROM dbo.VW_Education_Comfort_SeekHelp_Treatment_2024
ORDER BY 
    Education,
    ComfortLevel;
GO