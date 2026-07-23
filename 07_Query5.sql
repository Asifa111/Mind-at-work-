SET NOCOUNT ON;
GO

/*========================================================
Business Question

In 2024, how do employee benefits availability and company
wellness program adoption vary across different levels of
mental health awareness across companies?

Uses:
- Fact_MentalHealthSummary_Quarter
- Dim_Date
- Dim_Company
- Dim_MentalHealthAwareness

Advanced SQL used:
- CTE
- Window Functions
========================================================*/

IF OBJECT_ID('dbo.VW_Q_Quarterly_Benefits_Wellness_Awareness_2024', 'V') IS NOT NULL
    DROP VIEW dbo.VW_Q_Quarterly_Benefits_Wellness_Awareness_2024;
GO

CREATE VIEW dbo.VW_Q_Quarterly_Benefits_Wellness_Awareness_2024
AS
WITH CTE_BenefitsWellness AS
(
    SELECT
        d.[Year],
        d.Quarter,
        d.QuarterName,
        c.CompanyID,
        c.TechCompany,
        c.CareOptions,
        c.WellnessProgram,
        ma.AwarenessLevelCurrent,
        ma.KnowledgeLevelCurrent,

        SUM(f.TotalEmployees) AS TotalEmployees,
        SUM(f.CountBenefitYes) AS TotalBenefitYes,
        SUM(f.CountWellnessProgramYes) AS TotalWellnessProgramYes
    FROM dbo.Fact_MentalHealthSummary_Quarter f
    INNER JOIN dbo.Dim_Date d
        ON f.QuarterID = d.DateID
    INNER JOIN dbo.Dim_Company c
        ON f.CompanyID = c.CompanyID
    INNER JOIN dbo.Dim_MentalHealthAwareness ma
        ON f.MentalHealthAwarenessID = ma.MentalHealthAwarenessID
    WHERE d.[Year] = 2024
    GROUP BY
        d.[Year],
        d.Quarter,
        d.QuarterName,
        c.CompanyID,
        c.TechCompany,
        c.CareOptions,
        c.WellnessProgram,
        ma.AwarenessLevelCurrent,
        ma.KnowledgeLevelCurrent
)
SELECT
    [Year],
    Quarter,
    QuarterName,
    CompanyID,
    TechCompany,
    CareOptions,
    WellnessProgram,
    AwarenessLevelCurrent,
    KnowledgeLevelCurrent,
    TotalEmployees,
    TotalBenefitYes,
    TotalWellnessProgramYes,

    CAST(
        CAST(
            TotalBenefitYes * 100.0
            / NULLIF(TotalEmployees, 0)
            AS DECIMAL(10,2)
        ) AS VARCHAR(20)
    ) + ' %' AS BenefitYesPercentage,

    CAST(
        CAST(
            TotalWellnessProgramYes * 100.0
            / NULLIF(TotalEmployees, 0)
            AS DECIMAL(10,2)
        ) AS VARCHAR(20)
    ) + ' %' AS WellnessProgramYesPercentage,

    SUM(TotalBenefitYes) OVER
    (
        PARTITION BY [Year], Quarter, AwarenessLevelCurrent
    ) AS QuarterAwarenessBenefitTotal,

    SUM(TotalWellnessProgramYes) OVER
    (
        PARTITION BY [Year], Quarter, AwarenessLevelCurrent
    ) AS QuarterAwarenessWellnessTotal,

    RANK() OVER
    (
        PARTITION BY [Year], Quarter
        ORDER BY TotalBenefitYes DESC
    ) AS BenefitRankWithinQuarter,

    RANK() OVER
    (
        PARTITION BY [Year], Quarter
        ORDER BY TotalWellnessProgramYes DESC
    ) AS WellnessRankWithinQuarter

FROM CTE_BenefitsWellness;
GO

SELECT *
FROM dbo.VW_Q_Quarterly_Benefits_Wellness_Awareness_2024
ORDER BY
    [Year],
    Quarter,
    CompanyID,
    AwarenessLevelCurrent,
    KnowledgeLevelCurrent;