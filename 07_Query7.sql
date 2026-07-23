/*========================================================
Business Question

In 2024, how do the counts of tech companies and care
options vary across the location hierarchy from country
to state?

Uses:
- Fact_MentalHealthSummary_Yearly
- Dim_Location
- Dim_Date

This view is designed for drill-down:
Country -> State
========================================================*/
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.VW_Q_Yearly_LocationHierarchy_TechCare_2024', 'V') IS NOT NULL
    DROP VIEW dbo.VW_Q_Yearly_LocationHierarchy_TechCare_2024;
GO

CREATE VIEW dbo.VW_Q_Yearly_LocationHierarchy_TechCare_2024
AS
SELECT
    d.[Year],

    l.Country,

    CASE
        WHEN GROUPING(l.State) = 1 THEN NULL
        ELSE l.State
    END AS State,

    CASE
        WHEN GROUPING(l.State) = 1 THEN 'Country Level'
        ELSE 'State Level'
    END AS GeographyLevel,

    SUM(f.CountTechCompany) AS TotalTechCompanies,
    SUM(f.CountCareOptions) AS TotalCareOptions
FROM dbo.Fact_MentalHealthSummary_Yearly f
INNER JOIN dbo.Dim_Location l
    ON f.LocationID = l.LocationID
INNER JOIN dbo.Dim_Date d
    ON f.YearID = d.DateID
WHERE d.[Year] = 2024
GROUP BY GROUPING SETS
(
    (d.[Year], l.Country),
    (d.[Year], l.Country, l.State)
);
GO
SELECT *
FROM dbo.VW_Q_Yearly_LocationHierarchy_TechCare_2024
ORDER BY
    Country,
    CASE WHEN State IS NULL THEN 0 ELSE 1 END,
    State;