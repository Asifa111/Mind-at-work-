SET NOCOUNT ON;
GO

/*========================================================
02_create_tables.sql
Purpose:
- create staging, transformed, dimension, and fact tables
========================================================*/

/*========================================================
STEP 1: DROP FACT TABLES FIRST
Reason:
Fact tables depend on dimension tables, so they must be
dropped before dimensions.
========================================================*/
DROP TABLE IF EXISTS dbo.Fact_MentalHealthSummary_Yearly;
DROP TABLE IF EXISTS dbo.Fact_MentalHealthSummary_Quarter;
DROP TABLE IF EXISTS dbo.Fact_MentalHealthSummary_Monthly;
DROP TABLE IF EXISTS dbo.Fact_MentalHealthObservation;
GO

/*========================================================
STEP 2: DROP DIMENSION TABLES
========================================================*/
/*--------------------------------------------------------
Remove foreign keys that may still reference the location
hierarchy tables from earlier versions of the schema.
This makes the script safer to rerun.
--------------------------------------------------------*/
DECLARE @DropFKSQL NVARCHAR(MAX) = N'';

SELECT @DropFKSQL = @DropFKSQL +
    N'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(parent.schema_id)) + N'.' + QUOTENAME(parent.name) +
    N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';' + CHAR(13) + CHAR(10)
FROM sys.foreign_keys fk
INNER JOIN sys.tables parent
    ON fk.parent_object_id = parent.object_id
WHERE fk.referenced_object_id IN
(
    OBJECT_ID(N'dbo.Dim_Location'),
    OBJECT_ID(N'dbo.LKP_State'),
    OBJECT_ID(N'dbo.LKP_Country')
);

IF @DropFKSQL <> N''
    EXEC sp_executesql @DropFKSQL;
GO

DROP TABLE IF EXISTS dbo.Dim_DiscussingMentalHealthAtWork;
DROP TABLE IF EXISTS dbo.Dim_MentalHealthAwareness;
DROP TABLE IF EXISTS dbo.Dim_Employment;
DROP TABLE IF EXISTS dbo.Dim_Company;
DROP TABLE IF EXISTS dbo.Dim_Person;
DROP TABLE IF EXISTS dbo.Dim_Location;
DROP TABLE IF EXISTS dbo.LKP_State;
DROP TABLE IF EXISTS dbo.LKP_Country;
DROP TABLE IF EXISTS dbo.Dim_Date;
GO

/*========================================================
STEP 3: DROP WORKING TABLES
These tables are used during loading and transformation.
========================================================*/
DROP TABLE IF EXISTS dbo.MentalHealth_Transformed;
DROP TABLE IF EXISTS dbo.MentalHealth_Staging;
DROP TABLE IF EXISTS dbo.MentalHealthWorkPlace_Staging;
DROP TABLE IF EXISTS dbo.AI_Staging;
GO

/*========================================================
STEP 4: CREATE STAGING TABLES
========================================================*/

CREATE TABLE dbo.MentalHealth_Staging
(
    [Date] VARCHAR(20) NULL,
    [Month] VARCHAR(20) NULL,
    [Day] VARCHAR(20) NULL,
    [State] VARCHAR(100) NULL,
    [Gender] VARCHAR(50) NULL,
    [AgeGroup] VARCHAR(100) NULL,
    [Education] VARCHAR(150) NULL,
    [IncomeLevel] VARCHAR(150) NULL,
    [MentalHealthDays] INT NULL,
    [GeneralHealthStatus] VARCHAR(100) NULL,
    [SmokingStatus] VARCHAR(50) NULL,
    [ExerciseStatus] VARCHAR(50) NULL,
    [CheckUpStatus] VARCHAR(100) NULL
);
GO

CREATE TABLE dbo.MentalHealthWorkPlace_Staging
(
    [Age] VARCHAR(100) NULL,
    [Gender] VARCHAR(50) NULL,
    [Country] VARCHAR(100) NULL,
    [State] VARCHAR(100) NULL,
    [FamilyHistory] VARCHAR(50) NULL,
    [WorkInterference] VARCHAR(50) NULL,
    [RemoteWork] VARCHAR(50) NULL,
    [Benefits] VARCHAR(50) NULL,
    [SeekHelp] VARCHAR(50) NULL,
    [Treatment] VARCHAR(50) NULL,
    [NumEmployees] VARCHAR(50) NULL,
    [TechCompany] VARCHAR(50) NULL,
    [CareOptions] VARCHAR(50) NULL,
    [WellnessProgram] VARCHAR(50) NULL,
    [AwarenessLevel] VARCHAR(50) NULL,
    [KnowledgeLevel] VARCHAR(50) NULL,
    [ComfortLevel] VARCHAR(50) NULL,
    [ManagerSupport] VARCHAR(50) NULL
);
GO

CREATE TABLE dbo.AI_Staging
(
    [SourcePersonID] INT NULL,
    [Year] INT NULL,
    [Month] INT NULL,
    [Gender] VARCHAR(50) NULL,
    [AgeGroup] VARCHAR(100) NULL,
    [Education] VARCHAR(150) NULL,
    [IncomeLevel] VARCHAR(150) NULL,
    [FamilyHistory] VARCHAR(50) NULL,
    [Country] VARCHAR(100) NULL,
    [State] VARCHAR(100) NULL,
    [NumEmployees] VARCHAR(50) NULL,
    [TechCompany] VARCHAR(50) NULL,
    [CareOptions] VARCHAR(50) NULL,
    [WellnessProgram] VARCHAR(50) NULL,
    [RemoteWork] VARCHAR(50) NULL,
    [Benefits] VARCHAR(50) NULL,
    [WorkInterference] VARCHAR(50) NULL,
    [AwarenessLevel] VARCHAR(50) NULL,
    [KnowledgeLevel] VARCHAR(50) NULL,
    [ComfortLevel] VARCHAR(50) NULL,
    [ManagerSupport] VARCHAR(50) NULL,
    [MentalHealthDays] INT NULL,
    [SeekHelp] VARCHAR(50) NULL,
    [SmokingStatus] VARCHAR(50) NULL,
    [ExerciseStatus] VARCHAR(50) NULL,
    [Treatment] VARCHAR(50) NULL,
    [GeneralHealthStatus] VARCHAR(100) NULL,
    [FullDate] DATE NULL
);
GO

/*========================================================
STEP 5: CREATE TRANSFORMED TABLE
Purpose:
This is the cleaned and standardized integration layer.
It is useful before loading dimensions and facts.
========================================================*/
CREATE TABLE dbo.MentalHealth_Transformed
(
    TransformedID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
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

    NumEmployees VARCHAR(50) NULL,
    TechCompany VARCHAR(50) NULL,
    CareOptions VARCHAR(50) NULL,
    WellnessProgram VARCHAR(50) NULL,

    RemoteWork VARCHAR(50) NULL,
    Benefits VARCHAR(50) NULL,

    AwarenessLevel VARCHAR(50) NULL,
    KnowledgeLevel VARCHAR(50) NULL,
    ComfortLevel VARCHAR(50) NULL,
    ManagerSupport VARCHAR(50) NULL,

    WorkInterference VARCHAR(50) NULL,
    SeekHelp VARCHAR(50) NULL,
    SmokingStatus VARCHAR(50) NULL,
    ExerciseStatus VARCHAR(50) NULL,
    Treatment VARCHAR(50) NULL,
    GeneralHealthStatus VARCHAR(100) NULL,
    MentalHealthDays INT NULL,
    CheckUpStatus VARCHAR(100) NULL,

    RowHash VARBINARY(32) NULL,

    LoadTimestamp DATETIME2(0) NOT NULL
        CONSTRAINT DF_MentalHealth_Transformed_LoadTimestamp
        DEFAULT SYSDATETIME()
);
GO

/*========================================================
STEP 6: CREATE DIMENSION TABLES
========================================================*/

/*--------------------------------------------------------
LOOKUP: COUNTRY
Hierarchy Level 1
Stores the top level of the location hierarchy.
--------------------------------------------------------*/
CREATE TABLE dbo.LKP_Country
(
    CountryID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CountryName VARCHAR(100) NOT NULL,
    CONSTRAINT UQ_LKP_Country UNIQUE (CountryName)
);
GO

/*--------------------------------------------------------
LOOKUP: STATE
Hierarchy Level 2
Each state belongs to one country.
--------------------------------------------------------*/
CREATE TABLE dbo.LKP_State
(
    StateID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    StateCode VARCHAR(20) NULL,
    StateName VARCHAR(100) NOT NULL,
    CountryID INT NOT NULL,
    CONSTRAINT UQ_LKP_State UNIQUE (StateName, CountryID),
    CONSTRAINT FK_LKP_State_Country FOREIGN KEY (CountryID)
        REFERENCES dbo.LKP_Country(CountryID)
);
GO

/*--------------------------------------------------------
DIMENSION: LOCATION
SCD Type 0
Proper hierarchy table using Country -> State.
The dimension stores keys to the hierarchy levels instead
of repeating country and state text in every row.
--------------------------------------------------------*/
CREATE TABLE dbo.Dim_Location
(
    LocationID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CountryID INT NOT NULL,
    StateID INT NOT NULL,
    CONSTRAINT UQ_Dim_Location UNIQUE (CountryID, StateID),
    CONSTRAINT FK_Dim_Location_Country FOREIGN KEY (CountryID)
        REFERENCES dbo.LKP_Country(CountryID),
    CONSTRAINT FK_Dim_Location_State FOREIGN KEY (StateID)
        REFERENCES dbo.LKP_State(StateID)
);
GO

/*--------------------------------------------------------
DIMENSION: PERSON
SCD Type 2
A new row is inserted when tracked person attributes change.
--------------------------------------------------------*/
CREATE TABLE dbo.Dim_Person
(
    PersonID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SourcePersonID INT NULL,
    Gender VARCHAR(50) NULL,
    AgeGroup VARCHAR(100) NULL,
    Education VARCHAR(150) NULL,
    IncomeLevel VARCHAR(150) NULL,
    FamilyHistory VARCHAR(50) NULL,
    EffectiveStartDate DATE NOT NULL,
    EffectiveEndDate DATE NULL,
    IsCurrent BIT NOT NULL
);
GO

/*--------------------------------------------------------
DIMENSION: COMPANY
SCD Type 2
Tracks company-related attributes over time.
--------------------------------------------------------*/
CREATE TABLE dbo.Dim_Company
(
    CompanyID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    NumEmployees VARCHAR(50) NULL,
    TechCompany VARCHAR(50) NULL,
    CareOptions VARCHAR(50) NULL,
    WellnessProgram VARCHAR(50) NULL,
    EffectiveStartDate DATE NOT NULL,
    EffectiveEndDate DATE NULL,
    IsCurrent BIT NOT NULL
);
GO

/*--------------------------------------------------------
DIMENSION: EMPLOYMENT
SCD Type 2
Tracks employment-related attributes over time.
--------------------------------------------------------*/
CREATE TABLE dbo.Dim_Employment
(
    EmploymentID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RemoteWork VARCHAR(50) NULL,
    Benefits VARCHAR(50) NULL,
    EffectiveStartDate DATE NOT NULL,
    EffectiveEndDate DATE NULL,
    IsCurrent BIT NOT NULL
);
GO

/*--------------------------------------------------------
DIMENSION: MENTAL HEALTH AWARENESS
SCD Type 3
Stores current and past awareness / knowledge values.
--------------------------------------------------------*/
CREATE TABLE dbo.Dim_MentalHealthAwareness
(
    MentalHealthAwarenessID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    AwarenessLevelCurrent VARCHAR(50) NULL,
    AwarenessLevelPast VARCHAR(50) NULL,
    KnowledgeLevelCurrent VARCHAR(50) NULL,
    KnowledgeLevelPast VARCHAR(50) NULL,
    CONSTRAINT UQ_Dim_MentalHealthAwareness UNIQUE
    (
        AwarenessLevelCurrent,
        AwarenessLevelPast,
        KnowledgeLevelCurrent,
        KnowledgeLevelPast
    )
);
GO

/*--------------------------------------------------------
DIMENSION: DISCUSSING MENTAL HEALTH AT WORK
SCD Type 3
Stores current and past comfort / manager support values.
--------------------------------------------------------*/
CREATE TABLE dbo.Dim_DiscussingMentalHealthAtWork
(
    DiscussingMentalHealthAtWorkID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ComfortLevelCurrent VARCHAR(50) NULL,
    ComfortLevelPast VARCHAR(50) NULL,
    ManagerSupportCurrent VARCHAR(50) NULL,
    ManagerSupportPast VARCHAR(50) NULL,
    CONSTRAINT UQ_Dim_DiscussingMentalHealthAtWork UNIQUE
    (
        ComfortLevelCurrent,
        ComfortLevelPast,
        ManagerSupportCurrent,
        ManagerSupportPast
    )
);
GO

/*--------------------------------------------------------
DIMENSION: DATE
SCD Type 0
DateID is not an identity. It should be loaded explicitly
during date dimension population.
--------------------------------------------------------*/
CREATE TABLE dbo.Dim_Date
(
    DateID INT NOT NULL PRIMARY KEY,
    FullDate DATE NOT NULL,
    [Day] INT NOT NULL,
    DayName VARCHAR(20) NOT NULL,
    [Month] INT NOT NULL,
    MonthName VARCHAR(20) NOT NULL,
    Quarter INT NOT NULL,
    QuarterName VARCHAR(10) NOT NULL,
    [Year] INT NOT NULL,
    CONSTRAINT UQ_Dim_Date_FullDate UNIQUE (FullDate)
);
GO

/*========================================================
STEP 7: CREATE FACT TABLES
========================================================*/

/*--------------------------------------------------------
FACT: TRANSACTIONAL SNAPSHOT
Grain:
One observation for a person, employment setting,
discussion-at-work setting, and date.
Matches the ERD transactional snapshot fact.
--------------------------------------------------------*/
CREATE TABLE dbo.Fact_MentalHealthObservation
(
    PersonID INT NOT NULL,
    EmploymentID INT NOT NULL,
    DiscussingMentalHealthAtWorkID INT NOT NULL,
    DateID INT NOT NULL,

    ObservationCount INT NOT NULL
        CONSTRAINT DF_Fact_MentalHealthObservation_ObservationCount DEFAULT (1),

    WorkInterference VARCHAR(50) NULL,
    SeekHelp VARCHAR(50) NULL,
    SmokingStatus VARCHAR(50) NULL,
    ExerciseStatus VARCHAR(50) NULL,
    Treatment VARCHAR(50) NULL,
    GeneralHealthStatus VARCHAR(100) NULL,

    CONSTRAINT PK_Fact_MentalHealthObservation PRIMARY KEY
    (
        PersonID,
        EmploymentID,
        DiscussingMentalHealthAtWorkID,
        DateID
    ),

    CONSTRAINT FK_FMO_Person FOREIGN KEY (PersonID)
        REFERENCES dbo.Dim_Person(PersonID),

    CONSTRAINT FK_FMO_Employment FOREIGN KEY (EmploymentID)
        REFERENCES dbo.Dim_Employment(EmploymentID),

    CONSTRAINT FK_FMO_Discussing FOREIGN KEY (DiscussingMentalHealthAtWorkID)
        REFERENCES dbo.Dim_DiscussingMentalHealthAtWork(DiscussingMentalHealthAtWorkID),

    CONSTRAINT FK_FMO_Date FOREIGN KEY (DateID)
        REFERENCES dbo.Dim_Date(DateID)
);
GO

/*--------------------------------------------------------
FACT: MONTHLY SUMMARY
Cumulative fact
Matches the ERD monthly summary fact.
--------------------------------------------------------*/
CREATE TABLE dbo.Fact_MentalHealthSummary_Monthly
(
    CompanyID INT NOT NULL,
    EmploymentID INT NOT NULL,
    MentalHealthAwarenessID INT NOT NULL,
    MonthID INT NOT NULL,

    TotalPersons INT NOT NULL,
    AvgMentalHealthDays DECIMAL(18,2) NOT NULL,
    AvgHighDistressCount DECIMAL(18,2) NOT NULL,
    CountBenefitYes INT NOT NULL,

    CONSTRAINT PK_Fact_MentalHealthSummary_Monthly PRIMARY KEY
    (
        CompanyID,
        EmploymentID,
        MentalHealthAwarenessID,
        MonthID
    ),

    CONSTRAINT FK_FMSM_Company FOREIGN KEY (CompanyID)
        REFERENCES dbo.Dim_Company(CompanyID),

    CONSTRAINT FK_FMSM_Employment FOREIGN KEY (EmploymentID)
        REFERENCES dbo.Dim_Employment(EmploymentID),

    CONSTRAINT FK_FMSM_Awareness FOREIGN KEY (MentalHealthAwarenessID)
        REFERENCES dbo.Dim_MentalHealthAwareness(MentalHealthAwarenessID),

    CONSTRAINT FK_FMSM_Date FOREIGN KEY (MonthID)
        REFERENCES dbo.Dim_Date(DateID)
);
GO

/*--------------------------------------------------------
FACT: QUARTERLY SUMMARY
Cumulative fact
Matches the ERD quarterly summary fact.
--------------------------------------------------------*/
CREATE TABLE dbo.Fact_MentalHealthSummary_Quarter
(
    MentalHealthAwarenessID INT NOT NULL,
    QuarterID INT NOT NULL,
    CompanyID INT NOT NULL,

    TotalEmployees INT NOT NULL,
    CountBenefitYes INT NOT NULL,
    CountWellnessProgramYes INT NOT NULL,

    CONSTRAINT PK_Fact_MentalHealthSummary_Quarter PRIMARY KEY
    (
        MentalHealthAwarenessID,
        QuarterID,
        CompanyID
    ),

    CONSTRAINT FK_FMSQ_Awareness FOREIGN KEY (MentalHealthAwarenessID)
        REFERENCES dbo.Dim_MentalHealthAwareness(MentalHealthAwarenessID),

    CONSTRAINT FK_FMSQ_Date FOREIGN KEY (QuarterID)
        REFERENCES dbo.Dim_Date(DateID),

    CONSTRAINT FK_FMSQ_Company FOREIGN KEY (CompanyID)
        REFERENCES dbo.Dim_Company(CompanyID)
);
GO

/*--------------------------------------------------------
FACT: YEARLY SUMMARY
Cumulative fact
Matches the ERD yearly summary fact.
--------------------------------------------------------*/
CREATE TABLE dbo.Fact_MentalHealthSummary_Yearly
(
    CompanyID INT NOT NULL,
    LocationID INT NOT NULL,
    YearID INT NOT NULL,

    CountTechCompany INT NOT NULL,
    CountCareOptions INT NOT NULL,

    CONSTRAINT PK_Fact_MentalHealthSummary_Yearly PRIMARY KEY
    (
        CompanyID,
        LocationID,
        YearID
    ),

    CONSTRAINT FK_FMSY_Company FOREIGN KEY (CompanyID)
        REFERENCES dbo.Dim_Company(CompanyID),

    CONSTRAINT FK_FMSY_Location FOREIGN KEY (LocationID)
        REFERENCES dbo.Dim_Location(LocationID),

    CONSTRAINT FK_FMSY_Date FOREIGN KEY (YearID)
        REFERENCES dbo.Dim_Date(DateID)
);
GO

/*========================================================
STEP 8: CREATE INDEXES
Purpose:
These indexes support common joins and lookups during ETL
and reporting.
========================================================*/

/*--------------------------------------------------------
TRANSFORMED TABLE INDEXES
--------------------------------------------------------*/
CREATE NONCLUSTERED INDEX IX_MentalHealth_Transformed_SourcePersonID
ON dbo.MentalHealth_Transformed (SourcePersonID);

CREATE NONCLUSTERED INDEX IX_MentalHealth_Transformed_FullDate
ON dbo.MentalHealth_Transformed (FullDate);

CREATE NONCLUSTERED INDEX IX_MentalHealth_Transformed_SourceSystem_PersonDate
ON dbo.MentalHealth_Transformed (SourceSystem, SourcePersonID, FullDate);

CREATE NONCLUSTERED INDEX IX_MentalHealth_Transformed_RowHash
ON dbo.MentalHealth_Transformed (RowHash);
GO

/*--------------------------------------------------------
DIMENSION INDEXES
--------------------------------------------------------*/
CREATE NONCLUSTERED INDEX IX_Dim_Date_Year_Month
ON dbo.Dim_Date ([Year], [Month]);

CREATE NONCLUSTERED INDEX IX_Dim_Date_Year_Quarter
ON dbo.Dim_Date ([Year], Quarter);

CREATE NONCLUSTERED INDEX IX_LKP_Country_CountryName
ON dbo.LKP_Country (CountryName);

CREATE NONCLUSTERED INDEX IX_LKP_State_CountryID_StateName
ON dbo.LKP_State (CountryID, StateName);

CREATE NONCLUSTERED INDEX IX_Dim_Location_CountryID_StateID
ON dbo.Dim_Location (CountryID, StateID);

CREATE NONCLUSTERED INDEX IX_Dim_Person_SourcePersonID_Current
ON dbo.Dim_Person (SourcePersonID, IsCurrent)
INCLUDE (PersonID, EffectiveStartDate, EffectiveEndDate);

CREATE NONCLUSTERED INDEX IX_Dim_Company_Current_Search
ON dbo.Dim_Company (IsCurrent, NumEmployees, TechCompany, CareOptions, WellnessProgram)
INCLUDE (CompanyID, EffectiveStartDate, EffectiveEndDate);

CREATE NONCLUSTERED INDEX IX_Dim_Employment_Current_Search
ON dbo.Dim_Employment (IsCurrent, RemoteWork, Benefits)
INCLUDE (EmploymentID, EffectiveStartDate, EffectiveEndDate);

CREATE NONCLUSTERED INDEX IX_Dim_MentalHealthAwareness_Current
ON dbo.Dim_MentalHealthAwareness (AwarenessLevelCurrent, KnowledgeLevelCurrent)
INCLUDE (AwarenessLevelPast, KnowledgeLevelPast);

CREATE NONCLUSTERED INDEX IX_Dim_DiscussingMentalHealthAtWork_Current
ON dbo.Dim_DiscussingMentalHealthAtWork (ComfortLevelCurrent, ManagerSupportCurrent)
INCLUDE (ComfortLevelPast, ManagerSupportPast);
GO

/*--------------------------------------------------------
FACT TABLE INDEXES
--------------------------------------------------------*/
CREATE NONCLUSTERED INDEX IX_FMO_DateID
ON dbo.Fact_MentalHealthObservation (DateID)
INCLUDE
(
    ObservationCount,
    WorkInterference,
    SeekHelp,
    SmokingStatus,
    ExerciseStatus,
    Treatment,
    GeneralHealthStatus
);

CREATE NONCLUSTERED INDEX IX_FMSM_MonthID
ON dbo.Fact_MentalHealthSummary_Monthly (MonthID)
INCLUDE
(
    TotalPersons,
    AvgMentalHealthDays,
    AvgHighDistressCount,
    CountBenefitYes
);

CREATE NONCLUSTERED INDEX IX_FMSQ_QuarterID
ON dbo.Fact_MentalHealthSummary_Quarter (QuarterID)
INCLUDE
(
    TotalEmployees,
    CountBenefitYes,
    CountWellnessProgramYes
);

CREATE NONCLUSTERED INDEX IX_FMSY_YearID
ON dbo.Fact_MentalHealthSummary_Yearly (YearID)
INCLUDE
(
    CountTechCompany,
    CountCareOptions
);
GO
