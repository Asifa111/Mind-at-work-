SET NOCOUNT ON;
GO

/*========================================================
Business Question

In 2024, how do monthly average high distress counts differ
across different employee mental health awareness levels?

(Using PIVOT)
========================================================*/

;WITH MonthlyAwareness AS
(
    SELECT
        d.[Year],
        d.MonthName,
        ma.AwarenessLevelCurrent AS AwarenessLevel,

        CAST(
            SUM(CAST(f.AvgHighDistressCount AS DECIMAL(18,2)))
            / NULLIF(SUM(f.TotalPersons), 0)
            AS DECIMAL(10,2)
        ) AS AvgHighDistressPerPerson
    FROM dbo.Fact_MentalHealthSummary_Monthly f
    INNER JOIN dbo.Dim_MentalHealthAwareness ma
        ON f.MentalHealthAwarenessID = ma.MentalHealthAwarenessID
    INNER JOIN dbo.Dim_Date d
        ON f.MonthID = d.DateID
    WHERE d.[Year] = 2024
    GROUP BY
        d.[Year],
        d.MonthName,
        ma.AwarenessLevelCurrent
)
SELECT
    [Year],
    MonthName,
    [High],
    [Medium],
    [Low]
FROM MonthlyAwareness
PIVOT
(
    MAX(AvgHighDistressPerPerson)
    FOR AwarenessLevel IN ([High], [Medium], [Low])
) AS PivotTable
ORDER BY
    CASE MonthName
        WHEN 'January' THEN 1
        WHEN 'February' THEN 2
        WHEN 'March' THEN 3
        WHEN 'April' THEN 4
        WHEN 'May' THEN 5
        WHEN 'June' THEN 6
        WHEN 'July' THEN 7
        WHEN 'August' THEN 8
        WHEN 'September' THEN 9
        WHEN 'October' THEN 10
        WHEN 'November' THEN 11
        WHEN 'December' THEN 12
    END;
GO