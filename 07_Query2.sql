/*========================================================

In 2024, how do average mental health days vary across different months for employees based on 
their remote work status (remote vs non-remote)?


STEP 0: DROP INDEX IF EXISTS
========================================================*/
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_MV_Q_RemoteWork_Monthly_2024'
      AND object_id = OBJECT_ID('dbo.MV_Q_RemoteWork_Monthly_2024')
)
BEGIN
    DROP INDEX IX_MV_Q_RemoteWork_Monthly_2024
    ON dbo.MV_Q_RemoteWork_Monthly_2024;
END
GO

/*========================================================
STEP 1: DROP VIEW IF EXISTS
========================================================*/
IF OBJECT_ID('dbo.MV_Q_RemoteWork_Monthly_2024', 'V') IS NOT NULL
    DROP VIEW dbo.MV_Q_RemoteWork_Monthly_2024;
GO

-- Create View
CREATE VIEW dbo.MV_Q_RemoteWork_Monthly_2024
WITH SCHEMABINDING
AS
SELECT
    d.[Year],
    d.[Month],
    d.MonthName,
    e.RemoteWork,

    COUNT_BIG(*) AS RecordCount,
    SUM(f.TotalPersons) AS TotalPersons,
    SUM(CAST(f.AvgMentalHealthDays AS DECIMAL(18,4)) * CAST(f.TotalPersons AS DECIMAL(18,4))) AS TotalMentalHealthDaysWeighted

FROM dbo.Fact_MentalHealthSummary_Monthly AS f
INNER JOIN dbo.Dim_Date AS d
    ON f.MonthID = d.DateID
INNER JOIN dbo.Dim_Employment AS e
    ON f.EmploymentID = e.EmploymentID

WHERE d.[Year] = 2024

GROUP BY
    d.[Year],
    d.[Month],
    d.MonthName,
    e.RemoteWork;
GO

-- Display Result from View
SELECT
    [Year],
    MonthName,
    RemoteWork,
    TotalPersons,
    CAST(
        ROUND(
            TotalMentalHealthDaysWeighted * 1.0 / NULLIF(TotalPersons, 0),
            2
        ) AS DECIMAL(10,2)
    ) AS AvgMentalHealthDays
FROM dbo.MV_Q_RemoteWork_Monthly_2024
ORDER BY
    [Year],
    [Month],
    RemoteWork;