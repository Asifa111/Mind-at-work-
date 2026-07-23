SET NOCOUNT ON;
GO

/*========================================================
Business Question

In 2024, how does work interference due to mental health
vary across employees by gender and family history of
mental health conditions?

Uses:
- Fact_MentalHealthObservation
- Dim_Person
- Dim_Date
========================================================*/

IF OBJECT_ID('dbo.VW_Q_WorkInterference_ByGenderFamily_2024', 'V') IS NOT NULL
    DROP VIEW dbo.VW_Q_WorkInterference_ByGenderFamily_2024;
GO

CREATE VIEW dbo.VW_Q_WorkInterference_ByGenderFamily_2024
AS
SELECT
    d.[Year],
    p.Gender,
    p.FamilyHistory,
    f.WorkInterference,
    COUNT(*) AS TotalObservations,
    CAST(
        CAST(
            COUNT(*) * 100.0
            / NULLIF(
                SUM(COUNT(*)) OVER
                (
                    PARTITION BY d.[Year], p.Gender, p.FamilyHistory
                ),
                0
            )
            AS DECIMAL(10,2)
        ) AS VARCHAR(20)
    ) + ' %' AS WorkInterferencePercentage
FROM dbo.Fact_MentalHealthObservation f
INNER JOIN dbo.Dim_Person p
    ON f.PersonID = p.PersonID
INNER JOIN dbo.Dim_Date d
    ON f.DateID = d.DateID
WHERE d.[Year] = 2024
GROUP BY
    d.[Year],
    p.Gender,
    p.FamilyHistory,
    f.WorkInterference;
GO
SELECT *
FROM dbo.VW_Q_WorkInterference_ByGenderFamily_2024
ORDER BY Gender, FamilyHistory, WorkInterference;