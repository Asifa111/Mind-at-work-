SET NOCOUNT ON;
GO

/*========================================================
06_load_Dim_Facts.sql
Purpose:
- Resolve standardized values from MentalHealth_Transformed
- Maintain dimensions, including SCD Type 2 and Type 3 logic
- Rebuild fact tables from the resolved integrated dataset
- Keep the script clean and aligned with the current ERD

Notes:
- Dim_Person uses true SCD Type 2 because SourcePersonID exists.
- Dim_Company and Dim_Employment do not have a stable business key
  in the source, so their procedures insert new attribute combinations
  and preserve existing rows. They keep SCD columns, but automatic
  expiration of old rows is not deterministic without a source key.
- Dim_Location is reloaded directly from the lookup hierarchy
  using LKP_Country and LKP_State.
========================================================*/

PRINT 'Starting 06_load_Dim_Facts.sql ...';
GO

/*========================================================
STEP 0: DROP TEMP TABLES IF THEY ALREADY EXIST
========================================================*/
IF OBJECT_ID('tempdb..#ResolvedSource_Base', 'U') IS NOT NULL
    DROP TABLE #ResolvedSource_Base;
GO

IF OBJECT_ID('tempdb..#ResolvedSource', 'U') IS NOT NULL
    DROP TABLE #ResolvedSource;
GO

/*========================================================
STEP 1: CREATE / UPDATE ROW-BY-ROW SCD PROCEDURES
These procedures process one row at a time.
========================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Upsert_Dim_Person_SCD2
(
    @SourcePersonID     VARCHAR(100),
    @Gender             VARCHAR(100),
    @AgeGroup           VARCHAR(100),
    @Education          VARCHAR(150),
    @IncomeLevel        VARCHAR(150),
    @FamilyHistory      VARCHAR(100),
    @EffectiveStartDate DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentPersonID INT;

    SELECT TOP (1)
        @CurrentPersonID = dp.PersonID
    FROM dbo.Dim_Person dp
    WHERE dp.SourcePersonID = @SourcePersonID
      AND dp.IsCurrent = 1
    ORDER BY dp.EffectiveStartDate DESC, dp.PersonID DESC;

    /*----------------------------------------------------
    Brand new person -> insert new current row.
    ----------------------------------------------------*/
    IF @CurrentPersonID IS NULL
    BEGIN
        INSERT INTO dbo.Dim_Person
        (
            SourcePersonID,
            Gender,
            AgeGroup,
            Education,
            IncomeLevel,
            FamilyHistory,
            EffectiveStartDate,
            EffectiveEndDate,
            IsCurrent
        )
        VALUES
        (
            @SourcePersonID,
            @Gender,
            @AgeGroup,
            @Education,
            @IncomeLevel,
            @FamilyHistory,
            @EffectiveStartDate,
            NULL,
            1
        );

        RETURN;
    END;

    /*----------------------------------------------------
    Exact duplicate of current row -> skip.
    ----------------------------------------------------*/
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Dim_Person dp
        WHERE dp.PersonID = @CurrentPersonID
          AND ISNULL(dp.Gender, '') = ISNULL(@Gender, '')
          AND ISNULL(dp.AgeGroup, '') = ISNULL(@AgeGroup, '')
          AND ISNULL(dp.Education, '') = ISNULL(@Education, '')
          AND ISNULL(dp.IncomeLevel, '') = ISNULL(@IncomeLevel, '')
          AND ISNULL(dp.FamilyHistory, '') = ISNULL(@FamilyHistory, '')
    )
    BEGIN
        RETURN;
    END;

    /*----------------------------------------------------
    Attributes changed -> expire old row and insert new row.
    ----------------------------------------------------*/
    UPDATE dbo.Dim_Person
    SET EffectiveEndDate = DATEADD(DAY, -1, @EffectiveStartDate),
        IsCurrent = 0
    WHERE PersonID = @CurrentPersonID;

    INSERT INTO dbo.Dim_Person
    (
        SourcePersonID,
        Gender,
        AgeGroup,
        Education,
        IncomeLevel,
        FamilyHistory,
        EffectiveStartDate,
        EffectiveEndDate,
        IsCurrent
    )
    VALUES
    (
        @SourcePersonID,
        @Gender,
        @AgeGroup,
        @Education,
        @IncomeLevel,
        @FamilyHistory,
        @EffectiveStartDate,
        NULL,
        1
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Upsert_Dim_Company_SCD2
(
    @NumEmployees        VARCHAR(100),
    @TechCompany         VARCHAR(100),
    @CareOptions         VARCHAR(100),
    @WellnessProgram     VARCHAR(100),
    @EffectiveStartDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    /*----------------------------------------------------
    No stable company business key exists in the source.
    So row-by-row logic here means:
    - exact same attribute combination exists -> skip
    - new attribute combination -> insert new row
    ----------------------------------------------------*/
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Dim_Company dc
        WHERE ISNULL(dc.NumEmployees, '') = ISNULL(@NumEmployees, '')
          AND ISNULL(dc.TechCompany, '') = ISNULL(@TechCompany, '')
          AND ISNULL(dc.CareOptions, '') = ISNULL(@CareOptions, '')
          AND ISNULL(dc.WellnessProgram, '') = ISNULL(@WellnessProgram, '')
    )
    BEGIN
        RETURN;
    END;

    INSERT INTO dbo.Dim_Company
    (
        NumEmployees,
        TechCompany,
        CareOptions,
        WellnessProgram,
        EffectiveStartDate,
        EffectiveEndDate,
        IsCurrent
    )
    VALUES
    (
        @NumEmployees,
        @TechCompany,
        @CareOptions,
        @WellnessProgram,
        ISNULL(@EffectiveStartDate, CAST('1900-01-01' AS DATE)),
        NULL,
        1
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Upsert_Dim_Employment_SCD2
(
    @RemoteWork          VARCHAR(100),
    @Benefits            VARCHAR(100),
    @EffectiveStartDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    /*----------------------------------------------------
    No stable employment business key exists in the source.
    So row-by-row logic here means:
    - exact same attribute combination exists -> skip
    - new attribute combination -> insert new row
    ----------------------------------------------------*/
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Dim_Employment de
        WHERE ISNULL(de.RemoteWork, '') = ISNULL(@RemoteWork, '')
          AND ISNULL(de.Benefits, '') = ISNULL(@Benefits, '')
    )
    BEGIN
        RETURN;
    END;

    INSERT INTO dbo.Dim_Employment
    (
        RemoteWork,
        Benefits,
        EffectiveStartDate,
        EffectiveEndDate,
        IsCurrent
    )
    VALUES
    (
        @RemoteWork,
        @Benefits,
        ISNULL(@EffectiveStartDate, CAST('1900-01-01' AS DATE)),
        NULL,
        1
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Upsert_Dim_MentalHealthAwareness_SCD3
(
    @AwarenessLevelCurrent  VARCHAR(100),
    @AwarenessLevelPast     VARCHAR(100),
    @KnowledgeLevelCurrent  VARCHAR(100),
    @KnowledgeLevelPast     VARCHAR(100)
)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Dim_MentalHealthAwareness d
        WHERE ISNULL(d.AwarenessLevelCurrent, '') = ISNULL(@AwarenessLevelCurrent, '')
          AND ISNULL(d.AwarenessLevelPast, '') = ISNULL(@AwarenessLevelPast, '')
          AND ISNULL(d.KnowledgeLevelCurrent, '') = ISNULL(@KnowledgeLevelCurrent, '')
          AND ISNULL(d.KnowledgeLevelPast, '') = ISNULL(@KnowledgeLevelPast, '')
    )
    BEGIN
        RETURN;
    END;

    INSERT INTO dbo.Dim_MentalHealthAwareness
    (
        AwarenessLevelCurrent,
        AwarenessLevelPast,
        KnowledgeLevelCurrent,
        KnowledgeLevelPast
    )
    VALUES
    (
        @AwarenessLevelCurrent,
        @AwarenessLevelPast,
        @KnowledgeLevelCurrent,
        @KnowledgeLevelPast
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Upsert_Dim_DiscussingMentalHealthAtWork_SCD3
(
    @ComfortLevelCurrent    VARCHAR(100),
    @ComfortLevelPast       VARCHAR(100),
    @ManagerSupportCurrent  VARCHAR(100),
    @ManagerSupportPast     VARCHAR(100)
)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Dim_DiscussingMentalHealthAtWork d
        WHERE ISNULL(d.ComfortLevelCurrent, '') = ISNULL(@ComfortLevelCurrent, '')
          AND ISNULL(d.ComfortLevelPast, '') = ISNULL(@ComfortLevelPast, '')
          AND ISNULL(d.ManagerSupportCurrent, '') = ISNULL(@ManagerSupportCurrent, '')
          AND ISNULL(d.ManagerSupportPast, '') = ISNULL(@ManagerSupportPast, '')
    )
    BEGIN
        RETURN;
    END;

    INSERT INTO dbo.Dim_DiscussingMentalHealthAtWork
    (
        ComfortLevelCurrent,
        ComfortLevelPast,
        ManagerSupportCurrent,
        ManagerSupportPast
    )
    VALUES
    (
        @ComfortLevelCurrent,
        @ComfortLevelPast,
        @ManagerSupportCurrent,
        @ManagerSupportPast
    );
END;
GO

/*========================================================
STEP 2: CLEAR FACTS ONLY
Dimensions are maintained incrementally, except Dim_Location
which is reloaded from the lookup hierarchy in STEP 6.
========================================================*/
DELETE FROM dbo.Fact_MentalHealthSummary_Yearly;
DELETE FROM dbo.Fact_MentalHealthSummary_Quarter;
DELETE FROM dbo.Fact_MentalHealthSummary_Monthly;
DELETE FROM dbo.Fact_MentalHealthObservation;
GO

/*========================================================
STEP 3: BUILD RESOLVED SOURCE BASE
This step standardizes transformed rows using lookup tables.
========================================================*/
SELECT
    t.SourceSystem,
    t.SourcePersonID,
    CAST(t.FullDate AS DATE) AS FullDate,

    COALESCE(g.GenderValue, gm.GenderValue, 'Not Found') AS Gender,
    COALESCE(ag.AgeGroupValue, agm.AgeGroupValue, 'Not Found') AS AgeGroup,
    COALESCE(ed.EducationValue, edm.EducationValue, NULLIF(LTRIM(RTRIM(CAST(t.Education AS VARCHAR(150)))), ''), 'Not Found') AS Education,
    COALESCE(il.IncomeLevelValue, ilm.IncomeLevelValue, NULLIF(LTRIM(RTRIM(CAST(t.IncomeLevel AS VARCHAR(150)))), ''), 'Not Found') AS IncomeLevel,
    COALESCE(fhm.FamilyHistoryValue, 'Not Found') AS FamilyHistory,

    COALESCE(rc.ResolvedCountryID, nf_country.CountryID) AS CountryID,
    COALESCE(rc.ResolvedCountryName, 'Not Found') AS CountryName,
    COALESCE(rs_state.ResolvedStateID, nf_state_resolved.ResolvedStateID) AS StateID,
    COALESCE(rs_state.ResolvedStateName, nf_state_resolved.ResolvedStateName, 'Not Found') AS StateName,

    COALESCE(rwm.RemoteWorkValue, 'Not Found') AS RemoteWork,
    COALESCE(bem.BenefitsValue, 'Not Found') AS Benefits,
    COALESCE(nem.NumEmployeesValue, 'Not Found') AS NumEmployees,
    COALESCE(tcm.TechCompanyValue, 'Not Found') AS TechCompany,
    COALESCE(comap.CareOptionsValue, 'Not Found') AS CareOptions,
    COALESCE(wpm.WellnessProgramValue, 'Not Found') AS WellnessProgram,
    COALESCE(wim.WorkInterferenceValue, 'Not Found') AS WorkInterference,

    COALESCE(alm.AwarenessLevelValue, 'Not Found') AS AwarenessLevel,
    COALESCE(klm.KnowledgeLevelValue, 'Not Found') AS KnowledgeLevel,
    COALESCE(clm.ComfortLevelValue, 'Not Found') AS ComfortLevel,
    COALESCE(msm.ManagerSupportValue, 'Not Found') AS ManagerSupport,

    CASE
        WHEN TRY_CAST(t.MentalHealthDays AS INT) BETWEEN 0 AND 30
            THEN TRY_CAST(t.MentalHealthDays AS INT)
        ELSE NULL
    END AS MentalHealthDays,

    COALESCE(gh.GeneralHealthStatusValue, ghm.GeneralHealthStatusValue, 'Not Found') AS GeneralHealthStatus,
    COALESCE(ss.SmokingStatusValue, ssm.SmokingStatusValue, 'Not Found') AS SmokingStatus,
    COALESCE(es.ExerciseStatusValue, esm.ExerciseStatusValue, 'Not Found') AS ExerciseStatus,
    COALESCE(cu.CheckUpStatusValue, cum.CheckUpStatusValue, 'Not Found') AS CheckUpStatus,
    COALESCE(shm.SeekHelpValue, 'Not Found') AS SeekHelp,
    COALESCE(tr.TreatmentValue, 'Not Found') AS Treatment,
    COALESCE(tr.TreatmentBinaryFlag, 0) AS TreatmentFlag
INTO #ResolvedSource_Base
FROM dbo.MentalHealth_Transformed t

LEFT JOIN dbo.LKP_Gender g
       ON CAST(TRY_CAST(TRY_CAST(t.Gender AS FLOAT) AS INT) AS VARCHAR(20)) = g.GenderCode
LEFT JOIN dbo.LKP_AgeGroup ag
       ON CAST(TRY_CAST(TRY_CAST(t.AgeGroup AS FLOAT) AS INT) AS VARCHAR(20)) = ag.AgeGroupCode
LEFT JOIN dbo.LKP_Education ed
       ON CAST(TRY_CAST(TRY_CAST(t.Education AS FLOAT) AS INT) AS VARCHAR(20)) = ed.EducationCode
LEFT JOIN dbo.LKP_IncomeLevel il
       ON CAST(TRY_CAST(TRY_CAST(t.IncomeLevel AS FLOAT) AS INT) AS VARCHAR(20)) = il.IncomeLevelCode
LEFT JOIN dbo.LKP_Country ct
       ON CAST(t.Country AS VARCHAR(100)) = ct.CountryName
LEFT JOIN dbo.LKP_State st
       ON TRY_CAST(TRY_CAST(t.State AS FLOAT) AS INT) = st.StateCode
LEFT JOIN dbo.LKP_GeneralHealthStatus gh
       ON CAST(TRY_CAST(TRY_CAST(t.GeneralHealthStatus AS FLOAT) AS INT) AS VARCHAR(20)) = gh.GeneralHealthStatusCode
LEFT JOIN dbo.LKP_SmokingStatus ss
       ON CAST(TRY_CAST(TRY_CAST(t.SmokingStatus AS FLOAT) AS INT) AS VARCHAR(20)) = ss.SmokingStatusCode
LEFT JOIN dbo.LKP_ExerciseStatus es
       ON CAST(TRY_CAST(TRY_CAST(t.ExerciseStatus AS FLOAT) AS INT) AS VARCHAR(20)) = es.ExerciseStatusCode
LEFT JOIN dbo.LKP_CheckUpStatus cu
       ON CAST(TRY_CAST(TRY_CAST(t.CheckUpStatus AS FLOAT) AS INT) AS VARCHAR(20)) = cu.CheckUpStatusCode

LEFT JOIN dbo.LKP_Gender_Map gm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.Gender AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(gm_map.RawGenderValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_Gender gm
       ON gm.GenderID = gm_map.GenderID

LEFT JOIN dbo.LKP_AgeGroup_Map agm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.AgeGroup AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(agm_map.RawAgeGroupValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_AgeGroup agm
       ON agm.AgeGroupID = agm_map.AgeGroupID

LEFT JOIN dbo.LKP_Education_Map edm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.Education AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(edm_map.RawEducationValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_Education edm
       ON edm.EducationID = edm_map.EducationID

LEFT JOIN dbo.LKP_IncomeLevel_Map ilm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.IncomeLevel AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(ilm_map.RawIncomeLevelValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_IncomeLevel ilm
       ON ilm.IncomeLevelID = ilm_map.IncomeLevelID

LEFT JOIN dbo.LKP_Country_Map ctm_map
       ON dbo.fn_NormalizeCountryValue(CAST(t.Country AS VARCHAR(255)))
        = dbo.fn_NormalizeCountryValue(CAST(ctm_map.RawCountryValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_Country ctm
       ON ctm.CountryID = ctm_map.CountryID

LEFT JOIN dbo.LKP_State_Map stm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.State AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(stm_map.RawStateValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_State stm
       ON stm.StateID = stm_map.StateID

OUTER APPLY
(
    SELECT
        COALESCE(ct.CountryID, ctm.CountryID, st.CountryID, stm.CountryID, (SELECT TOP (1) c.CountryID FROM dbo.LKP_Country c WHERE c.CountryName = 'Not Found')) AS ResolvedCountryID,
        COALESCE
        (
            ct.CountryName,
            ctm.CountryName,
            (SELECT TOP (1) c.CountryName FROM dbo.LKP_Country c WHERE c.CountryID = st.CountryID),
            (SELECT TOP (1) c.CountryName FROM dbo.LKP_Country c WHERE c.CountryID = stm.CountryID),
            'Not Found'
        ) AS ResolvedCountryName
) rc
OUTER APPLY
(
    SELECT TOP (1)
        s.StateID AS ResolvedStateID,
        s.StateName AS ResolvedStateName
    FROM dbo.LKP_State s
    WHERE s.StateID IN (st.StateID, stm.StateID)
      AND s.CountryID = rc.ResolvedCountryID
    ORDER BY CASE
                 WHEN s.StateID = st.StateID THEN 1
                 WHEN s.StateID = stm.StateID THEN 2
                 ELSE 3
             END
) rs_state
OUTER APPLY
(
    SELECT TOP (1)
        s.StateID AS ResolvedStateID,
        s.StateName AS ResolvedStateName
    FROM dbo.LKP_State s
    WHERE s.StateName = 'Not Found'
      AND (s.CountryID = rc.ResolvedCountryID OR s.CountryID = (SELECT TOP (1) c.CountryID FROM dbo.LKP_Country c WHERE c.CountryName = 'Not Found'))
    ORDER BY CASE
                 WHEN s.CountryID = rc.ResolvedCountryID THEN 1
                 ELSE 2
             END
) nf_state_resolved

LEFT JOIN dbo.LKP_FamilyHistory_Map fhm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.FamilyHistory AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(fhm_map.RawFamilyHistoryValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_FamilyHistory fhm
       ON fhm.FamilyHistoryID = fhm_map.FamilyHistoryID

LEFT JOIN dbo.LKP_WorkInterference_Map wim_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.WorkInterference AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(wim_map.RawWorkInterferenceValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_WorkInterference wim
       ON wim.WorkInterferenceID = wim_map.WorkInterferenceID

LEFT JOIN dbo.LKP_RemoteWork_Map rwm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.RemoteWork AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(rwm_map.RawRemoteWorkValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_RemoteWork rwm
       ON rwm.RemoteWorkID = rwm_map.RemoteWorkID

LEFT JOIN dbo.LKP_Benefits_Map bem_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.Benefits AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(bem_map.RawBenefitsValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_Benefits bem
       ON bem.BenefitsID = bem_map.BenefitsID

LEFT JOIN dbo.LKP_SeekHelp_Map shm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.SeekHelp AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(shm_map.RawSeekHelpValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_SeekHelp shm
       ON shm.SeekHelpID = shm_map.SeekHelpID

LEFT JOIN dbo.LKP_Treatment_Map trm
       ON dbo.fn_NormalizeLookupValue(CAST(t.Treatment AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(trm.RawTreatmentValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_Treatment tr
       ON tr.TreatmentID = trm.TreatmentID

LEFT JOIN dbo.LKP_NumEmployees_Map nem_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.NumEmployees AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(nem_map.RawNumEmployeesValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_NumEmployees nem
       ON nem.NumEmployeesID = nem_map.NumEmployeesID

LEFT JOIN dbo.LKP_TechCompany_Map tcm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.TechCompany AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(tcm_map.RawTechCompanyValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_TechCompany tcm
       ON tcm.TechCompanyID = tcm_map.TechCompanyID

LEFT JOIN dbo.LKP_CareOptions_Map com_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.CareOptions AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(com_map.RawCareOptionsValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_CareOptions comap
       ON comap.CareOptionsID = com_map.CareOptionsID

LEFT JOIN dbo.LKP_WellnessProgram_Map wpm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.WellnessProgram AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(wpm_map.RawWellnessProgramValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_WellnessProgram wpm
       ON wpm.WellnessProgramID = wpm_map.WellnessProgramID

LEFT JOIN dbo.LKP_AwarenessLevel_Map alm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.AwarenessLevel AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(alm_map.RawAwarenessLevelValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_AwarenessLevel alm
       ON alm.AwarenessLevelID = alm_map.AwarenessLevelID

LEFT JOIN dbo.LKP_KnowledgeLevel_Map klm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.KnowledgeLevel AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(klm_map.RawKnowledgeLevelValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_KnowledgeLevel klm
       ON klm.KnowledgeLevelID = klm_map.KnowledgeLevelID

LEFT JOIN dbo.LKP_ComfortLevel_Map clm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.ComfortLevel AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(clm_map.RawComfortLevelValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_ComfortLevel clm
       ON clm.ComfortLevelID = clm_map.ComfortLevelID

LEFT JOIN dbo.LKP_ManagerSupport_Map msm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.ManagerSupport AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(msm_map.RawManagerSupportValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_ManagerSupport msm
       ON msm.ManagerSupportID = msm_map.ManagerSupportID

LEFT JOIN dbo.LKP_GeneralHealthStatus_Map ghm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.GeneralHealthStatus AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(ghm_map.RawGeneralHealthStatusValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_GeneralHealthStatus ghm
       ON ghm.GeneralHealthStatusID = ghm_map.GeneralHealthStatusID

LEFT JOIN dbo.LKP_SmokingStatus_Map ssm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.SmokingStatus AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(ssm_map.RawSmokingStatusValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_SmokingStatus ssm
       ON ssm.SmokingStatusID = ssm_map.SmokingStatusID

LEFT JOIN dbo.LKP_ExerciseStatus_Map esm_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.ExerciseStatus AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(esm_map.RawExerciseStatusValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_ExerciseStatus esm
       ON esm.ExerciseStatusID = esm_map.ExerciseStatusID

LEFT JOIN dbo.LKP_CheckUpStatus_Map cum_map
       ON dbo.fn_NormalizeLookupValue(CAST(t.CheckUpStatus AS VARCHAR(255)))
        = dbo.fn_NormalizeLookupValue(CAST(cum_map.RawCheckUpStatusValue AS VARCHAR(255)))
LEFT JOIN dbo.LKP_CheckUpStatus cum
       ON cum.CheckUpStatusID = cum_map.CheckUpStatusID

CROSS JOIN
(
    SELECT TOP 1 CountryID
    FROM dbo.LKP_Country
    WHERE CountryName = 'Not Found'
) nf_country
CROSS JOIN
(
    SELECT TOP 1 StateID
    FROM dbo.LKP_State s
    INNER JOIN dbo.LKP_Country c
        ON c.CountryID = s.CountryID
    WHERE s.StateName = 'Not Found'
      AND c.CountryName = 'Not Found'
) nf_state;
GO

/*========================================================
STEP 4: BUILD RESOLVED SOURCE WITH SCD TYPE 3 VALUES
Past values come from the prior row for the same person.
========================================================*/
;WITH OrderedSource AS
(
    SELECT
        b.*,
        LAG(b.AwarenessLevel) OVER
        (
            PARTITION BY b.SourcePersonID
            ORDER BY b.FullDate,
                     b.SourceSystem,
                     b.AwarenessLevel,
                     b.KnowledgeLevel,
                     b.ComfortLevel,
                     b.ManagerSupport
        ) AS PrevAwarenessLevel,
        LAG(b.KnowledgeLevel) OVER
        (
            PARTITION BY b.SourcePersonID
            ORDER BY b.FullDate,
                     b.SourceSystem,
                     b.AwarenessLevel,
                     b.KnowledgeLevel,
                     b.ComfortLevel,
                     b.ManagerSupport
        ) AS PrevKnowledgeLevel,
        LAG(b.ComfortLevel) OVER
        (
            PARTITION BY b.SourcePersonID
            ORDER BY b.FullDate,
                     b.SourceSystem,
                     b.AwarenessLevel,
                     b.KnowledgeLevel,
                     b.ComfortLevel,
                     b.ManagerSupport
        ) AS PrevComfortLevel,
        LAG(b.ManagerSupport) OVER
        (
            PARTITION BY b.SourcePersonID
            ORDER BY b.FullDate,
                     b.SourceSystem,
                     b.AwarenessLevel,
                     b.KnowledgeLevel,
                     b.ComfortLevel,
                     b.ManagerSupport
        ) AS PrevManagerSupport
    FROM #ResolvedSource_Base b
)
SELECT
    SourceSystem,
    SourcePersonID,
    FullDate,
    Gender,
    AgeGroup,
    Education,
    IncomeLevel,
    FamilyHistory,
    CountryID,
    CountryName,
    StateID,
    StateName,
    RemoteWork,
    Benefits,
    NumEmployees,
    TechCompany,
    CareOptions,
    WellnessProgram,
    WorkInterference,
    AwarenessLevel,
    COALESCE(PrevAwarenessLevel, 'Not Found') AS AwarenessLevelPast,
    KnowledgeLevel,
    COALESCE(PrevKnowledgeLevel, 'Not Found') AS KnowledgeLevelPast,
    ComfortLevel,
    COALESCE(PrevComfortLevel, 'Not Found') AS ComfortLevelPast,
    ManagerSupport,
    COALESCE(PrevManagerSupport, 'Not Found') AS ManagerSupportPast,
    MentalHealthDays,
    GeneralHealthStatus,
    SmokingStatus,
    ExerciseStatus,
    CheckUpStatus,
    SeekHelp,
    Treatment,
    TreatmentFlag
INTO #ResolvedSource
FROM OrderedSource;
GO

/*========================================================
STEP 5: LOAD DIM_DATE
========================================================*/
INSERT INTO dbo.Dim_Date
(
    DateID,
    FullDate,
    [Day],
    DayName,
    [Month],
    MonthName,
    Quarter,
    QuarterName,
    [Year]
)
SELECT
    CAST(CONVERT(VARCHAR(8), d.FullDate, 112) AS INT) AS DateID,
    d.FullDate,
    DATEPART(DAY, d.FullDate),
    DATENAME(WEEKDAY, d.FullDate),
    DATEPART(MONTH, d.FullDate),
    DATENAME(MONTH, d.FullDate),
    DATEPART(QUARTER, d.FullDate),
    CONCAT('Q', DATEPART(QUARTER, d.FullDate)),
    DATEPART(YEAR, d.FullDate)
FROM
(
    SELECT DISTINCT FullDate
    FROM #ResolvedSource
    WHERE FullDate IS NOT NULL
) d
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Dim_Date x
    WHERE x.FullDate = d.FullDate
);
GO

/*========================================================
STEP 6: RELOAD DIM_LOCATION FROM LOOKUP HIERARCHY
Goal:
- keep the hierarchy relationship valid
- actually store the state and country names in Dim_Location
- also keep CountryID / StateID if those columns already exist

This block is written to work with either of these designs:
1) Dim_Location has only Country and State name columns
2) Dim_Location has CountryID / StateID and also Country / State columns
========================================================*/
IF COL_LENGTH('dbo.Dim_Location', 'Country') IS NULL
BEGIN
    ALTER TABLE dbo.Dim_Location ADD Country VARCHAR(100) NULL;
END;
GO

IF COL_LENGTH('dbo.Dim_Location', 'State') IS NULL
BEGIN
    ALTER TABLE dbo.Dim_Location ADD State VARCHAR(100) NULL;
END;
GO

DELETE FROM dbo.Dim_Location;
GO

IF COL_LENGTH('dbo.Dim_Location', 'CountryID') IS NOT NULL
   AND COL_LENGTH('dbo.Dim_Location', 'StateID') IS NOT NULL
BEGIN
    INSERT INTO dbo.Dim_Location
    (
        CountryID,
        StateID,
        Country,
        State
    )
    SELECT DISTINCT
        lc.CountryID,
        ls.StateID,
        lc.CountryName AS Country,
        ls.StateName   AS State
    FROM dbo.LKP_State ls
    INNER JOIN dbo.LKP_Country lc
        ON lc.CountryID = ls.CountryID
    WHERE lc.CountryName IS NOT NULL
      AND ls.StateName IS NOT NULL;
END
ELSE
BEGIN
    INSERT INTO dbo.Dim_Location
    (
        Country,
        State
    )
    SELECT DISTINCT
        lc.CountryName AS Country,
        ls.StateName   AS State
    FROM dbo.LKP_State ls
    INNER JOIN dbo.LKP_Country lc
        ON lc.CountryID = ls.CountryID
    WHERE lc.CountryName IS NOT NULL
      AND ls.StateName IS NOT NULL;
END;
GO

/*========================================================
STEP 7: LOAD SCD TYPE 2 DIMENSIONS ROW BY ROW
========================================================*/
DECLARE
    @SourcePersonID_Person     VARCHAR(100),
    @Gender_Person             VARCHAR(100),
    @AgeGroup_Person           VARCHAR(100),
    @Education_Person          VARCHAR(150),
    @IncomeLevel_Person        VARCHAR(150),
    @FamilyHistory_Person      VARCHAR(100),
    @EffectiveStartDate_Person DATE;

DECLARE person_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT DISTINCT
    CAST(rs.SourcePersonID AS VARCHAR(100)),
    CAST(rs.Gender AS VARCHAR(100)),
    CAST(rs.AgeGroup AS VARCHAR(100)),
    CAST(rs.Education AS VARCHAR(150)),
    CAST(rs.IncomeLevel AS VARCHAR(150)),
    CAST(rs.FamilyHistory AS VARCHAR(100)),
    rs.FullDate
FROM #ResolvedSource rs
WHERE rs.SourcePersonID IS NOT NULL
  AND rs.FullDate IS NOT NULL
ORDER BY CAST(rs.SourcePersonID AS VARCHAR(100)), rs.FullDate;

OPEN person_cursor;
FETCH NEXT FROM person_cursor INTO
    @SourcePersonID_Person,
    @Gender_Person,
    @AgeGroup_Person,
    @Education_Person,
    @IncomeLevel_Person,
    @FamilyHistory_Person,
    @EffectiveStartDate_Person;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_Upsert_Dim_Person_SCD2
        @SourcePersonID = @SourcePersonID_Person,
        @Gender = @Gender_Person,
        @AgeGroup = @AgeGroup_Person,
        @Education = @Education_Person,
        @IncomeLevel = @IncomeLevel_Person,
        @FamilyHistory = @FamilyHistory_Person,
        @EffectiveStartDate = @EffectiveStartDate_Person;

    FETCH NEXT FROM person_cursor INTO
        @SourcePersonID_Person,
        @Gender_Person,
        @AgeGroup_Person,
        @Education_Person,
        @IncomeLevel_Person,
        @FamilyHistory_Person,
        @EffectiveStartDate_Person;
END;

CLOSE person_cursor;
DEALLOCATE person_cursor;
GO

DECLARE
    @NumEmployees_Company        VARCHAR(100),
    @TechCompany_Company         VARCHAR(100),
    @CareOptions_Company         VARCHAR(100),
    @WellnessProgram_Company     VARCHAR(100),
    @EffectiveStartDate_Company  DATE;

DECLARE company_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT DISTINCT
    CAST(rs.NumEmployees AS VARCHAR(100)),
    CAST(rs.TechCompany AS VARCHAR(100)),
    CAST(rs.CareOptions AS VARCHAR(100)),
    CAST(rs.WellnessProgram AS VARCHAR(100)),
    COALESCE(rs.FullDate, CAST('1900-01-01' AS DATE))
FROM #ResolvedSource rs
ORDER BY
    CAST(rs.NumEmployees AS VARCHAR(100)),
    CAST(rs.TechCompany AS VARCHAR(100)),
    CAST(rs.CareOptions AS VARCHAR(100)),
    CAST(rs.WellnessProgram AS VARCHAR(100)),
    COALESCE(rs.FullDate, CAST('1900-01-01' AS DATE));

OPEN company_cursor;
FETCH NEXT FROM company_cursor INTO
    @NumEmployees_Company,
    @TechCompany_Company,
    @CareOptions_Company,
    @WellnessProgram_Company,
    @EffectiveStartDate_Company;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_Upsert_Dim_Company_SCD2
        @NumEmployees = @NumEmployees_Company,
        @TechCompany = @TechCompany_Company,
        @CareOptions = @CareOptions_Company,
        @WellnessProgram = @WellnessProgram_Company,
        @EffectiveStartDate = @EffectiveStartDate_Company;

    FETCH NEXT FROM company_cursor INTO
        @NumEmployees_Company,
        @TechCompany_Company,
        @CareOptions_Company,
        @WellnessProgram_Company,
        @EffectiveStartDate_Company;
END;

CLOSE company_cursor;
DEALLOCATE company_cursor;
GO

DECLARE
    @RemoteWork_Employment         VARCHAR(100),
    @Benefits_Employment           VARCHAR(100),
    @EffectiveStartDate_Employment DATE;

DECLARE employment_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT DISTINCT
    CAST(rs.RemoteWork AS VARCHAR(100)),
    CAST(rs.Benefits AS VARCHAR(100)),
    COALESCE(rs.FullDate, CAST('1900-01-01' AS DATE))
FROM #ResolvedSource rs
ORDER BY
    CAST(rs.RemoteWork AS VARCHAR(100)),
    CAST(rs.Benefits AS VARCHAR(100)),
    COALESCE(rs.FullDate, CAST('1900-01-01' AS DATE));

OPEN employment_cursor;
FETCH NEXT FROM employment_cursor INTO
    @RemoteWork_Employment,
    @Benefits_Employment,
    @EffectiveStartDate_Employment;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_Upsert_Dim_Employment_SCD2
        @RemoteWork = @RemoteWork_Employment,
        @Benefits = @Benefits_Employment,
        @EffectiveStartDate = @EffectiveStartDate_Employment;

    FETCH NEXT FROM employment_cursor INTO
        @RemoteWork_Employment,
        @Benefits_Employment,
        @EffectiveStartDate_Employment;
END;

CLOSE employment_cursor;
DEALLOCATE employment_cursor;
GO

/*========================================================
STEP 8: LOAD SCD TYPE 3 DIMENSIONS ROW BY ROW
========================================================*/
DECLARE
    @AwarenessLevelCurrent_Aw     VARCHAR(100),
    @AwarenessLevelPast_Aw        VARCHAR(100),
    @KnowledgeLevelCurrent_Aw     VARCHAR(100),
    @KnowledgeLevelPast_Aw        VARCHAR(100);

DECLARE awareness_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT DISTINCT
    CAST(rs.AwarenessLevel AS VARCHAR(100)),
    CAST(rs.AwarenessLevelPast AS VARCHAR(100)),
    CAST(rs.KnowledgeLevel AS VARCHAR(100)),
    CAST(rs.KnowledgeLevelPast AS VARCHAR(100))
FROM #ResolvedSource rs
ORDER BY
    CAST(rs.AwarenessLevel AS VARCHAR(100)),
    CAST(rs.AwarenessLevelPast AS VARCHAR(100)),
    CAST(rs.KnowledgeLevel AS VARCHAR(100)),
    CAST(rs.KnowledgeLevelPast AS VARCHAR(100));

OPEN awareness_cursor;
FETCH NEXT FROM awareness_cursor INTO
    @AwarenessLevelCurrent_Aw,
    @AwarenessLevelPast_Aw,
    @KnowledgeLevelCurrent_Aw,
    @KnowledgeLevelPast_Aw;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_Upsert_Dim_MentalHealthAwareness_SCD3
        @AwarenessLevelCurrent = @AwarenessLevelCurrent_Aw,
        @AwarenessLevelPast = @AwarenessLevelPast_Aw,
        @KnowledgeLevelCurrent = @KnowledgeLevelCurrent_Aw,
        @KnowledgeLevelPast = @KnowledgeLevelPast_Aw;

    FETCH NEXT FROM awareness_cursor INTO
        @AwarenessLevelCurrent_Aw,
        @AwarenessLevelPast_Aw,
        @KnowledgeLevelCurrent_Aw,
        @KnowledgeLevelPast_Aw;
END;

CLOSE awareness_cursor;
DEALLOCATE awareness_cursor;
GO

DECLARE
    @ComfortLevelCurrent_Disc    VARCHAR(100),
    @ComfortLevelPast_Disc       VARCHAR(100),
    @ManagerSupportCurrent_Disc  VARCHAR(100),
    @ManagerSupportPast_Disc     VARCHAR(100);

DECLARE discussing_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT DISTINCT
    CAST(rs.ComfortLevel AS VARCHAR(100)),
    CAST(rs.ComfortLevelPast AS VARCHAR(100)),
    CAST(rs.ManagerSupport AS VARCHAR(100)),
    CAST(rs.ManagerSupportPast AS VARCHAR(100))
FROM #ResolvedSource rs
ORDER BY
    CAST(rs.ComfortLevel AS VARCHAR(100)),
    CAST(rs.ComfortLevelPast AS VARCHAR(100)),
    CAST(rs.ManagerSupport AS VARCHAR(100)),
    CAST(rs.ManagerSupportPast AS VARCHAR(100));

OPEN discussing_cursor;
FETCH NEXT FROM discussing_cursor INTO
    @ComfortLevelCurrent_Disc,
    @ComfortLevelPast_Disc,
    @ManagerSupportCurrent_Disc,
    @ManagerSupportPast_Disc;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_Upsert_Dim_DiscussingMentalHealthAtWork_SCD3
        @ComfortLevelCurrent = @ComfortLevelCurrent_Disc,
        @ComfortLevelPast = @ComfortLevelPast_Disc,
        @ManagerSupportCurrent = @ManagerSupportCurrent_Disc,
        @ManagerSupportPast = @ManagerSupportPast_Disc;

    FETCH NEXT FROM discussing_cursor INTO
        @ComfortLevelCurrent_Disc,
        @ComfortLevelPast_Disc,
        @ManagerSupportCurrent_Disc,
        @ManagerSupportPast_Disc;
END;

CLOSE discussing_cursor;
DEALLOCATE discussing_cursor;
GO

/*========================================================
STEP 9: LOAD FACT_MENTALHEALTHOBSERVATION
Grain:
- one row per person + employment + discussing dimension + date
========================================================*/
INSERT INTO dbo.Fact_MentalHealthObservation
(
    PersonID,
    EmploymentID,
    DiscussingMentalHealthAtWorkID,
    DateID,
    ObservationCount,
    WorkInterference,
    SeekHelp,
    SmokingStatus,
    ExerciseStatus,
    Treatment,
    GeneralHealthStatus
)
SELECT
    p.PersonID,
    e.EmploymentID,
    dmh.DiscussingMentalHealthAtWorkID,
    dd.DateID,
    1,
    rs.WorkInterference,
    rs.SeekHelp,
    rs.SmokingStatus,
    rs.ExerciseStatus,
    rs.Treatment,
    rs.GeneralHealthStatus
FROM #ResolvedSource rs
INNER JOIN dbo.Dim_Date dd
    ON dd.FullDate = rs.FullDate
INNER JOIN dbo.Dim_Person p
    ON p.SourcePersonID = rs.SourcePersonID
   AND rs.FullDate >= p.EffectiveStartDate
   AND (p.EffectiveEndDate IS NULL OR rs.FullDate <= p.EffectiveEndDate)
INNER JOIN dbo.Dim_Employment e
    ON ISNULL(e.RemoteWork, '') = ISNULL(rs.RemoteWork, '')
   AND ISNULL(e.Benefits, '') = ISNULL(rs.Benefits, '')
   AND e.IsCurrent = 1
INNER JOIN dbo.Dim_DiscussingMentalHealthAtWork dmh
    ON ISNULL(dmh.ComfortLevelCurrent, '') = ISNULL(rs.ComfortLevel, '')
   AND ISNULL(dmh.ComfortLevelPast, '') = ISNULL(rs.ComfortLevelPast, '')
   AND ISNULL(dmh.ManagerSupportCurrent, '') = ISNULL(rs.ManagerSupport, '')
   AND ISNULL(dmh.ManagerSupportPast, '') = ISNULL(rs.ManagerSupportPast, '')
WHERE rs.SourcePersonID IS NOT NULL
  AND rs.FullDate IS NOT NULL;
GO

/*========================================================
STEP 10: LOAD FACT_MENTALHEALTHSUMMARY_MONTHLY
========================================================*/
;WITH MonthlyBase AS
(
    SELECT
        c.CompanyID,
        e.EmploymentID,
        a.MentalHealthAwarenessID,
        md.DateID AS MonthID,
        rs.SourcePersonID,
        rs.MentalHealthDays,
        CASE WHEN rs.MentalHealthDays >= 15 THEN 1 ELSE 0 END AS HighDistressFlag,
        CASE WHEN rs.Benefits = 'Yes' THEN 1 ELSE 0 END AS BenefitYesFlag
    FROM #ResolvedSource rs
    INNER JOIN dbo.Dim_Date d
        ON d.FullDate = rs.FullDate
    INNER JOIN dbo.Dim_Date md
        ON md.[Year] = d.[Year]
       AND md.[Month] = d.[Month]
       AND md.[Day] = 1
    INNER JOIN dbo.Dim_Company c
        ON ISNULL(c.NumEmployees, '') = ISNULL(rs.NumEmployees, '')
       AND ISNULL(c.TechCompany, '') = ISNULL(rs.TechCompany, '')
       AND ISNULL(c.CareOptions, '') = ISNULL(rs.CareOptions, '')
       AND ISNULL(c.WellnessProgram, '') = ISNULL(rs.WellnessProgram, '')
       AND c.IsCurrent = 1
    INNER JOIN dbo.Dim_Employment e
        ON ISNULL(e.RemoteWork, '') = ISNULL(rs.RemoteWork, '')
       AND ISNULL(e.Benefits, '') = ISNULL(rs.Benefits, '')
       AND e.IsCurrent = 1
    INNER JOIN dbo.Dim_MentalHealthAwareness a
        ON ISNULL(a.AwarenessLevelCurrent, '') = ISNULL(rs.AwarenessLevel, '')
       AND ISNULL(a.AwarenessLevelPast, '') = ISNULL(rs.AwarenessLevelPast, '')
       AND ISNULL(a.KnowledgeLevelCurrent, '') = ISNULL(rs.KnowledgeLevel, '')
       AND ISNULL(a.KnowledgeLevelPast, '') = ISNULL(rs.KnowledgeLevelPast, '')
    WHERE rs.SourcePersonID IS NOT NULL
      AND rs.FullDate IS NOT NULL
),
MonthlyAgg AS
(
    SELECT
        CompanyID,
        EmploymentID,
        MentalHealthAwarenessID,
        MonthID,
        COUNT(DISTINCT SourcePersonID) AS TotalPersons,
        CAST(AVG(CAST(MentalHealthDays AS DECIMAL(18,4))) AS DECIMAL(18,2)) AS AvgMentalHealthDays,
        CAST(AVG(CAST(HighDistressFlag AS DECIMAL(18,4))) AS DECIMAL(18,2)) AS AvgHighDistressCount,
        SUM(BenefitYesFlag) AS CountBenefitYes
    FROM MonthlyBase
    GROUP BY
        CompanyID,
        EmploymentID,
        MentalHealthAwarenessID,
        MonthID
)
INSERT INTO dbo.Fact_MentalHealthSummary_Monthly
(
    CompanyID,
    EmploymentID,
    MentalHealthAwarenessID,
    MonthID,
    TotalPersons,
    AvgMentalHealthDays,
    AvgHighDistressCount,
    CountBenefitYes
)
SELECT
    CompanyID,
    EmploymentID,
    MentalHealthAwarenessID,
    MonthID,
    TotalPersons,
    AvgMentalHealthDays,
    AvgHighDistressCount,
    CountBenefitYes
FROM MonthlyAgg;
GO

/*========================================================
STEP 11: LOAD FACT_MENTALHEALTHSUMMARY_QUARTER
========================================================*/
;WITH QuarterBase AS
(
    SELECT
        a.MentalHealthAwarenessID,
        qd.DateID AS QuarterID,
        c.CompanyID,
        rs.SourcePersonID,
        CASE WHEN rs.Benefits = 'Yes' THEN 1 ELSE 0 END AS BenefitYesFlag,
        CASE WHEN rs.WellnessProgram = 'Yes' THEN 1 ELSE 0 END AS WellnessProgramYesFlag
    FROM #ResolvedSource rs
    INNER JOIN dbo.Dim_Date d
        ON d.FullDate = rs.FullDate
    INNER JOIN dbo.Dim_Date qd
        ON qd.[Year] = d.[Year]
       AND qd.Quarter = d.Quarter
       AND qd.[Month] IN (1, 4, 7, 10)
       AND qd.[Day] = 1
    INNER JOIN dbo.Dim_Company c
        ON ISNULL(c.NumEmployees, '') = ISNULL(rs.NumEmployees, '')
       AND ISNULL(c.TechCompany, '') = ISNULL(rs.TechCompany, '')
       AND ISNULL(c.CareOptions, '') = ISNULL(rs.CareOptions, '')
       AND ISNULL(c.WellnessProgram, '') = ISNULL(rs.WellnessProgram, '')
       AND c.IsCurrent = 1
    INNER JOIN dbo.Dim_MentalHealthAwareness a
        ON ISNULL(a.AwarenessLevelCurrent, '') = ISNULL(rs.AwarenessLevel, '')
       AND ISNULL(a.AwarenessLevelPast, '') = ISNULL(rs.AwarenessLevelPast, '')
       AND ISNULL(a.KnowledgeLevelCurrent, '') = ISNULL(rs.KnowledgeLevel, '')
       AND ISNULL(a.KnowledgeLevelPast, '') = ISNULL(rs.KnowledgeLevelPast, '')
    WHERE rs.SourcePersonID IS NOT NULL
      AND rs.FullDate IS NOT NULL
),
QuarterAgg AS
(
    SELECT
        MentalHealthAwarenessID,
        QuarterID,
        CompanyID,
        COUNT(DISTINCT SourcePersonID) AS TotalEmployees,
        SUM(BenefitYesFlag) AS CountBenefitYes,
        SUM(WellnessProgramYesFlag) AS CountWellnessProgramYes
    FROM QuarterBase
    GROUP BY
        MentalHealthAwarenessID,
        QuarterID,
        CompanyID
)
INSERT INTO dbo.Fact_MentalHealthSummary_Quarter
(
    MentalHealthAwarenessID,
    QuarterID,
    CompanyID,
    TotalEmployees,
    CountBenefitYes,
    CountWellnessProgramYes
)
SELECT
    MentalHealthAwarenessID,
    QuarterID,
    CompanyID,
    TotalEmployees,
    CountBenefitYes,
    CountWellnessProgramYes
FROM QuarterAgg;
GO

/*========================================================
STEP 12: LOAD FACT_MENTALHEALTHSUMMARY_YEARLY
========================================================*/
;WITH YearDate AS
(
    SELECT
        [Year],
        MIN(DateID) AS YearID
    FROM dbo.Dim_Date
    GROUP BY [Year]
)
INSERT INTO dbo.Fact_MentalHealthSummary_Yearly
(
    CompanyID,
    LocationID,
    YearID,
    CountTechCompany,
    CountCareOptions
)
SELECT
    y.CompanyID,
    y.LocationID,
    y.YearID,
    SUM(y.TechCompanyFlag) AS CountTechCompany,
    SUM(y.CareOptionsFlag) AS CountCareOptions
FROM
(
    SELECT
        c.CompanyID,
        l.LocationID,
        yd.YearID,
        rs.SourcePersonID,
        CASE WHEN rs.TechCompany = 'Yes' THEN 1 ELSE 0 END AS TechCompanyFlag,
        CASE WHEN rs.CareOptions = 'Yes' THEN 1 ELSE 0 END AS CareOptionsFlag
    FROM #ResolvedSource rs
    INNER JOIN dbo.Dim_Date d
        ON d.FullDate = rs.FullDate
    INNER JOIN YearDate yd
        ON yd.[Year] = d.[Year]
    INNER JOIN dbo.Dim_Company c
        ON ISNULL(c.NumEmployees, '') = ISNULL(rs.NumEmployees, '')
       AND ISNULL(c.TechCompany, '') = ISNULL(rs.TechCompany, '')
       AND ISNULL(c.CareOptions, '') = ISNULL(rs.CareOptions, '')
       AND ISNULL(c.WellnessProgram, '') = ISNULL(rs.WellnessProgram, '')
       AND c.IsCurrent = 1
    INNER JOIN dbo.Dim_Location l
        ON l.CountryID = rs.CountryID
       AND l.StateID = rs.StateID
    WHERE rs.SourcePersonID IS NOT NULL
      AND rs.FullDate IS NOT NULL
) y
GROUP BY
    y.CompanyID,
    y.LocationID,
    y.YearID;
GO

/*========================================================
STEP 13: HIERARCHY VALIDATION FOR DIM_LOCATION
This should return 0 rows when Country/State names do not match lookup.
========================================================*/
SELECT
    dl.LocationID,
    dl.Country,
    dl.State,
    lc.CountryID,
    ls.StateID
FROM dbo.Dim_Location dl
LEFT JOIN dbo.LKP_Country lc
    ON dbo.fn_NormalizeCountryValue(CAST(dl.Country AS VARCHAR(255)))
     = dbo.fn_NormalizeCountryValue(CAST(lc.CountryName AS VARCHAR(255)))
LEFT JOIN dbo.LKP_State ls
    ON dbo.fn_NormalizeLookupValue(CAST(dl.State AS VARCHAR(255)))
     = dbo.fn_NormalizeLookupValue(CAST(ls.StateName AS VARCHAR(255)))
   AND ls.CountryID = lc.CountryID
WHERE lc.CountryID IS NULL
   OR ls.StateID IS NULL;
GO

/*========================================================
STEP 14: FINAL VALIDATION
Keep validation short and useful.
========================================================*/
SELECT 'Dim_Date' AS TableName, COUNT(*) AS TotalRows FROM dbo.Dim_Date
UNION ALL SELECT 'Dim_Location', COUNT(*) FROM dbo.Dim_Location
UNION ALL SELECT 'Dim_Person', COUNT(*) FROM dbo.Dim_Person
UNION ALL SELECT 'Dim_Company', COUNT(*) FROM dbo.Dim_Company
UNION ALL SELECT 'Dim_Employment', COUNT(*) FROM dbo.Dim_Employment
UNION ALL SELECT 'Dim_MentalHealthAwareness', COUNT(*) FROM dbo.Dim_MentalHealthAwareness
UNION ALL SELECT 'Dim_DiscussingMentalHealthAtWork', COUNT(*) FROM dbo.Dim_DiscussingMentalHealthAtWork
UNION ALL SELECT 'Fact_MentalHealthObservation', COUNT(*) FROM dbo.Fact_MentalHealthObservation
UNION ALL SELECT 'Fact_MentalHealthSummary_Monthly', COUNT(*) FROM dbo.Fact_MentalHealthSummary_Monthly
UNION ALL SELECT 'Fact_MentalHealthSummary_Quarter', COUNT(*) FROM dbo.Fact_MentalHealthSummary_Quarter
UNION ALL SELECT 'Fact_MentalHealthSummary_Yearly', COUNT(*) FROM dbo.Fact_MentalHealthSummary_Yearly;
GO

PRINT '06_load_Dim_Facts.sql completed successfully.';
GO

SELECT * FROM dbo.Dim_Location;
GO
