SET NOCOUNT ON;
GO

/*========================================================
04_create_lookup_tables.sql
Purpose:
- Create lookup tables and mapping tables
- Standardize raw values before dimension loading
- Keep only the required logic
- Remove extra debug / extra validation queries
========================================================*/

/*========================================================
STEP 1: DROP NORMALIZATION FUNCTIONS
========================================================*/
IF OBJECT_ID('dbo.fn_NormalizeLookupValue', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_NormalizeLookupValue;
GO

IF OBJECT_ID('dbo.fn_NormalizeCountryValue', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_NormalizeCountryValue;
GO

IF OBJECT_ID('dbo.fn_NormalizeMentalHealthDaysValue', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_NormalizeMentalHealthDaysValue;
GO

/*========================================================
STEP 2: CREATE NORMALIZATION FUNCTIONS
========================================================*/

/*--------------------------------------------------------
Normalize general lookup text:
- upper case
- remove hidden characters / punctuation
- trim extra spaces
- convert blanks to BLANK
--------------------------------------------------------*/
CREATE FUNCTION dbo.fn_NormalizeLookupValue
(
    @Input VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @x VARCHAR(255);

    SET @x = UPPER(ISNULL(@Input, ''));

    SET @x = REPLACE(@x, CHAR(9), ' ');
    SET @x = REPLACE(@x, CHAR(10), ' ');
    SET @x = REPLACE(@x, CHAR(13), ' ');
    SET @x = REPLACE(@x, CHAR(160), ' ');

    SET @x = REPLACE(@x, '’', '''');
    SET @x = REPLACE(@x, '`', '''');
    SET @x = REPLACE(@x, '"', '');
    SET @x = REPLACE(@x, '.', '');
    SET @x = REPLACE(@x, ',', '');
    SET @x = REPLACE(@x, ';', '');
    SET @x = REPLACE(@x, ':', '');
    SET @x = REPLACE(@x, '(', '');
    SET @x = REPLACE(@x, ')', '');
    SET @x = REPLACE(@x, '[', '');
    SET @x = REPLACE(@x, ']', '');

    SET @x = REPLACE(@x, '  ', ' ');
    SET @x = REPLACE(@x, '  ', ' ');
    SET @x = REPLACE(@x, '  ', ' ');
    SET @x = REPLACE(@x, '  ', ' ');

    SET @x = LTRIM(RTRIM(@x));

    IF @x = ''
        SET @x = 'BLANK';

    RETURN @x;
END;
GO

/*--------------------------------------------------------
Normalize country names into a standard form
--------------------------------------------------------*/
CREATE FUNCTION dbo.fn_NormalizeCountryValue
(
    @Input VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @x VARCHAR(255);

    SET @x = dbo.fn_NormalizeLookupValue(@Input);

    IF @x IN ('US', 'USA', 'U S A', 'UNITED STATES OF AMERICA', 'U S', 'AMERICA')
        SET @x = 'UNITED STATES';

    IF @x IN ('UK', 'U K', 'BRITAIN', 'GREAT BRITAIN', 'ENGLAND')
        SET @x = 'UNITED KINGDOM';

    RETURN @x;
END;
GO

/*--------------------------------------------------------
Normalize mental health day values
--------------------------------------------------------*/
CREATE FUNCTION dbo.fn_NormalizeMentalHealthDaysValue
(
    @Input VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @x VARCHAR(255);
    DECLARE @n INT;

    SET @x = dbo.fn_NormalizeLookupValue(@Input);

    IF @x IN ('NONE', 'NO DAYS')
        RETURN '0';

    SET @n = TRY_CAST(@x AS INT);

    IF @n BETWEEN 0 AND 30
        RETURN CAST(@n AS VARCHAR(10));

    IF @x IN ('77', '88', '99', 'BLANK', 'NOT FOUND')
        RETURN @x;

    RETURN 'NOT FOUND';
END;
GO

/*========================================================
STEP 3: DROP MAP TABLES
Map tables store raw-to-standardized mappings
========================================================*/
DROP TABLE IF EXISTS dbo.LKP_ManagerSupport_Map;
DROP TABLE IF EXISTS dbo.LKP_ComfortLevel_Map;
DROP TABLE IF EXISTS dbo.LKP_KnowledgeLevel_Map;
DROP TABLE IF EXISTS dbo.LKP_AwarenessLevel_Map;
DROP TABLE IF EXISTS dbo.LKP_WellnessProgram_Map;
DROP TABLE IF EXISTS dbo.LKP_CareOptions_Map;
DROP TABLE IF EXISTS dbo.LKP_TechCompany_Map;
DROP TABLE IF EXISTS dbo.LKP_NumEmployees_Map;
DROP TABLE IF EXISTS dbo.LKP_Treatment_Map;
DROP TABLE IF EXISTS dbo.LKP_SeekHelp_Map;
DROP TABLE IF EXISTS dbo.LKP_Benefits_Map;
DROP TABLE IF EXISTS dbo.LKP_RemoteWork_Map;
DROP TABLE IF EXISTS dbo.LKP_WorkInterference_Map;
DROP TABLE IF EXISTS dbo.LKP_FamilyHistory_Map;
DROP TABLE IF EXISTS dbo.LKP_CheckUpStatus_Map;
DROP TABLE IF EXISTS dbo.LKP_ExerciseStatus_Map;
DROP TABLE IF EXISTS dbo.LKP_SmokingStatus_Map;
DROP TABLE IF EXISTS dbo.LKP_GeneralHealthStatus_Map;
DROP TABLE IF EXISTS dbo.LKP_MentalHealthDays_Map;
DROP TABLE IF EXISTS dbo.LKP_IncomeLevel_Map;
DROP TABLE IF EXISTS dbo.LKP_Education_Map;
DROP TABLE IF EXISTS dbo.LKP_AgeGroup_Map;
DROP TABLE IF EXISTS dbo.LKP_Gender_Map;
DROP TABLE IF EXISTS dbo.LKP_State_Map;
DROP TABLE IF EXISTS dbo.LKP_Country_Map;
GO

/*========================================================
STEP 4: DROP MASTER LOOKUP TABLES
========================================================*/
DROP TABLE IF EXISTS dbo.LKP_ManagerSupport;
DROP TABLE IF EXISTS dbo.LKP_ComfortLevel;
DROP TABLE IF EXISTS dbo.LKP_KnowledgeLevel;
DROP TABLE IF EXISTS dbo.LKP_AwarenessLevel;
DROP TABLE IF EXISTS dbo.LKP_WellnessProgram;
DROP TABLE IF EXISTS dbo.LKP_CareOptions;
DROP TABLE IF EXISTS dbo.LKP_TechCompany;
DROP TABLE IF EXISTS dbo.LKP_NumEmployees;
DROP TABLE IF EXISTS dbo.LKP_Treatment;
DROP TABLE IF EXISTS dbo.LKP_SeekHelp;
DROP TABLE IF EXISTS dbo.LKP_Benefits;
DROP TABLE IF EXISTS dbo.LKP_RemoteWork;
DROP TABLE IF EXISTS dbo.LKP_WorkInterference;
DROP TABLE IF EXISTS dbo.LKP_FamilyHistory;
DROP TABLE IF EXISTS dbo.LKP_CheckUpStatus;
DROP TABLE IF EXISTS dbo.LKP_ExerciseStatus;
DROP TABLE IF EXISTS dbo.LKP_SmokingStatus;
DROP TABLE IF EXISTS dbo.LKP_GeneralHealthStatus;
DROP TABLE IF EXISTS dbo.LKP_MentalHealthDays;
DROP TABLE IF EXISTS dbo.LKP_IncomeLevel;
DROP TABLE IF EXISTS dbo.LKP_Education;
DROP TABLE IF EXISTS dbo.LKP_AgeGroup;
DROP TABLE IF EXISTS dbo.LKP_Gender;
GO

/*========================================================
STEP 5: CREATE MASTER LOOKUP TABLES
========================================================*/
/*--------------------------------------------------------
LOCATION HIERARCHY TABLES
LKP_Country and LKP_State are created in 02_create_tables.sql
and reused here.
--------------------------------------------------------*/

CREATE TABLE dbo.LKP_Gender
(
    GenderID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    GenderCode VARCHAR(20) NULL,
    GenderValue VARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_AgeGroup
(
    AgeGroupID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    AgeGroupCode VARCHAR(20) NULL,
    AgeGroupValue VARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_Education
(
    EducationID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    EducationCode VARCHAR(20) NULL,
    EducationValue VARCHAR(150) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_IncomeLevel
(
    IncomeLevelID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IncomeLevelCode VARCHAR(20) NULL,
    IncomeLevelValue VARCHAR(150) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_MentalHealthDays
(
    MentalHealthDaysID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    MentalHealthDaysCode VARCHAR(20) NULL,
    MentalHealthDaysValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_GeneralHealthStatus
(
    GeneralHealthStatusID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    GeneralHealthStatusCode VARCHAR(20) NULL,
    GeneralHealthStatusValue VARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_SmokingStatus
(
    SmokingStatusID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SmokingStatusCode VARCHAR(20) NULL,
    SmokingStatusValue VARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_ExerciseStatus
(
    ExerciseStatusID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ExerciseStatusCode VARCHAR(20) NULL,
    ExerciseStatusValue VARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_CheckUpStatus
(
    CheckUpStatusID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CheckUpStatusCode VARCHAR(20) NULL,
    CheckUpStatusValue VARCHAR(150) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_FamilyHistory
(
    FamilyHistoryID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    FamilyHistoryValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_WorkInterference
(
    WorkInterferenceID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    WorkInterferenceValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_RemoteWork
(
    RemoteWorkID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RemoteWorkValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_Benefits
(
    BenefitsID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    BenefitsValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_SeekHelp
(
    SeekHelpID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SeekHelpValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_Treatment
(
    TreatmentID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TreatmentValue VARCHAR(50) NOT NULL UNIQUE,
    TreatmentBinaryFlag INT NOT NULL
);
GO

CREATE TABLE dbo.LKP_NumEmployees
(
    NumEmployeesID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    NumEmployeesValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_TechCompany
(
    TechCompanyID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TechCompanyValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_CareOptions
(
    CareOptionsID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CareOptionsValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_WellnessProgram
(
    WellnessProgramID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    WellnessProgramValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_AwarenessLevel
(
    AwarenessLevelID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    AwarenessLevelValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_KnowledgeLevel
(
    KnowledgeLevelID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    KnowledgeLevelValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_ComfortLevel
(
    ComfortLevelID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ComfortLevelValue VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.LKP_ManagerSupport
(
    ManagerSupportID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ManagerSupportValue VARCHAR(50) NOT NULL UNIQUE
);
GO

/*========================================================
STEP 6: CREATE MAP TABLES
These tables map raw source values to standardized lookups
========================================================*/
CREATE TABLE dbo.LKP_Country_Map
(
    CountryMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawCountryValue VARCHAR(255) NOT NULL UNIQUE,
    CountryID INT NOT NULL,
    CONSTRAINT FK_LKP_Country_Map_Country FOREIGN KEY (CountryID)
        REFERENCES dbo.LKP_Country(CountryID)
);
GO

CREATE TABLE dbo.LKP_State_Map
(
    StateMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawStateValue VARCHAR(255) NOT NULL,
    CountryID INT NOT NULL,
    StateID INT NOT NULL,
    CONSTRAINT UQ_LKP_State_Map UNIQUE (RawStateValue, CountryID),
    CONSTRAINT FK_LKP_State_Map_Country FOREIGN KEY (CountryID)
        REFERENCES dbo.LKP_Country(CountryID),
    CONSTRAINT FK_LKP_State_Map_State FOREIGN KEY (StateID)
        REFERENCES dbo.LKP_State(StateID)
);
GO

CREATE TABLE dbo.LKP_Gender_Map
(
    GenderMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawGenderValue VARCHAR(255) NOT NULL UNIQUE,
    GenderID INT NOT NULL,
    CONSTRAINT FK_LKP_Gender_Map FOREIGN KEY (GenderID)
        REFERENCES dbo.LKP_Gender(GenderID)
);
GO

CREATE TABLE dbo.LKP_AgeGroup_Map
(
    AgeGroupMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawAgeGroupValue VARCHAR(255) NOT NULL UNIQUE,
    AgeGroupID INT NOT NULL,
    CONSTRAINT FK_LKP_AgeGroup_Map FOREIGN KEY (AgeGroupID)
        REFERENCES dbo.LKP_AgeGroup(AgeGroupID)
);
GO

CREATE TABLE dbo.LKP_Education_Map
(
    EducationMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawEducationValue VARCHAR(255) NOT NULL UNIQUE,
    EducationID INT NOT NULL,
    CONSTRAINT FK_LKP_Education_Map FOREIGN KEY (EducationID)
        REFERENCES dbo.LKP_Education(EducationID)
);
GO

CREATE TABLE dbo.LKP_IncomeLevel_Map
(
    IncomeLevelMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawIncomeLevelValue VARCHAR(255) NOT NULL UNIQUE,
    IncomeLevelID INT NOT NULL,
    CONSTRAINT FK_LKP_IncomeLevel_Map FOREIGN KEY (IncomeLevelID)
        REFERENCES dbo.LKP_IncomeLevel(IncomeLevelID)
);
GO

CREATE TABLE dbo.LKP_MentalHealthDays_Map
(
    MentalHealthDaysMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawMentalHealthDaysValue VARCHAR(255) NOT NULL UNIQUE,
    MentalHealthDaysID INT NOT NULL,
    CONSTRAINT FK_LKP_MentalHealthDays_Map FOREIGN KEY (MentalHealthDaysID)
        REFERENCES dbo.LKP_MentalHealthDays(MentalHealthDaysID)
);
GO

CREATE TABLE dbo.LKP_GeneralHealthStatus_Map
(
    GeneralHealthStatusMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawGeneralHealthStatusValue VARCHAR(255) NOT NULL UNIQUE,
    GeneralHealthStatusID INT NOT NULL,
    CONSTRAINT FK_LKP_GeneralHealthStatus_Map FOREIGN KEY (GeneralHealthStatusID)
        REFERENCES dbo.LKP_GeneralHealthStatus(GeneralHealthStatusID)
);
GO

CREATE TABLE dbo.LKP_SmokingStatus_Map
(
    SmokingStatusMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawSmokingStatusValue VARCHAR(255) NOT NULL UNIQUE,
    SmokingStatusID INT NOT NULL,
    CONSTRAINT FK_LKP_SmokingStatus_Map FOREIGN KEY (SmokingStatusID)
        REFERENCES dbo.LKP_SmokingStatus(SmokingStatusID)
);
GO

CREATE TABLE dbo.LKP_ExerciseStatus_Map
(
    ExerciseStatusMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawExerciseStatusValue VARCHAR(255) NOT NULL UNIQUE,
    ExerciseStatusID INT NOT NULL,
    CONSTRAINT FK_LKP_ExerciseStatus_Map FOREIGN KEY (ExerciseStatusID)
        REFERENCES dbo.LKP_ExerciseStatus(ExerciseStatusID)
);
GO

CREATE TABLE dbo.LKP_CheckUpStatus_Map
(
    CheckUpStatusMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawCheckUpStatusValue VARCHAR(255) NOT NULL UNIQUE,
    CheckUpStatusID INT NOT NULL,
    CONSTRAINT FK_LKP_CheckUpStatus_Map FOREIGN KEY (CheckUpStatusID)
        REFERENCES dbo.LKP_CheckUpStatus(CheckUpStatusID)
);
GO

CREATE TABLE dbo.LKP_FamilyHistory_Map
(
    FamilyHistoryMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawFamilyHistoryValue VARCHAR(255) NOT NULL UNIQUE,
    FamilyHistoryID INT NOT NULL,
    CONSTRAINT FK_LKP_FamilyHistory_Map FOREIGN KEY (FamilyHistoryID)
        REFERENCES dbo.LKP_FamilyHistory(FamilyHistoryID)
);
GO

CREATE TABLE dbo.LKP_WorkInterference_Map
(
    WorkInterferenceMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawWorkInterferenceValue VARCHAR(255) NOT NULL UNIQUE,
    WorkInterferenceID INT NOT NULL,
    CONSTRAINT FK_LKP_WorkInterference_Map FOREIGN KEY (WorkInterferenceID)
        REFERENCES dbo.LKP_WorkInterference(WorkInterferenceID)
);
GO

CREATE TABLE dbo.LKP_RemoteWork_Map
(
    RemoteWorkMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawRemoteWorkValue VARCHAR(255) NOT NULL UNIQUE,
    RemoteWorkID INT NOT NULL,
    CONSTRAINT FK_LKP_RemoteWork_Map FOREIGN KEY (RemoteWorkID)
        REFERENCES dbo.LKP_RemoteWork(RemoteWorkID)
);
GO

CREATE TABLE dbo.LKP_Benefits_Map
(
    BenefitsMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawBenefitsValue VARCHAR(255) NOT NULL UNIQUE,
    BenefitsID INT NOT NULL,
    CONSTRAINT FK_LKP_Benefits_Map FOREIGN KEY (BenefitsID)
        REFERENCES dbo.LKP_Benefits(BenefitsID)
);
GO

CREATE TABLE dbo.LKP_SeekHelp_Map
(
    SeekHelpMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawSeekHelpValue VARCHAR(255) NOT NULL UNIQUE,
    SeekHelpID INT NOT NULL,
    CONSTRAINT FK_LKP_SeekHelp_Map FOREIGN KEY (SeekHelpID)
        REFERENCES dbo.LKP_SeekHelp(SeekHelpID)
);
GO

CREATE TABLE dbo.LKP_Treatment_Map
(
    TreatmentMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawTreatmentValue VARCHAR(255) NOT NULL UNIQUE,
    TreatmentID INT NOT NULL,
    CONSTRAINT FK_LKP_Treatment_Map FOREIGN KEY (TreatmentID)
        REFERENCES dbo.LKP_Treatment(TreatmentID)
);
GO

CREATE TABLE dbo.LKP_NumEmployees_Map
(
    NumEmployeesMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawNumEmployeesValue VARCHAR(255) NOT NULL UNIQUE,
    NumEmployeesID INT NOT NULL,
    CONSTRAINT FK_LKP_NumEmployees_Map FOREIGN KEY (NumEmployeesID)
        REFERENCES dbo.LKP_NumEmployees(NumEmployeesID)
);
GO

CREATE TABLE dbo.LKP_TechCompany_Map
(
    TechCompanyMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawTechCompanyValue VARCHAR(255) NOT NULL UNIQUE,
    TechCompanyID INT NOT NULL,
    CONSTRAINT FK_LKP_TechCompany_Map FOREIGN KEY (TechCompanyID)
        REFERENCES dbo.LKP_TechCompany(TechCompanyID)
);
GO

CREATE TABLE dbo.LKP_CareOptions_Map
(
    CareOptionsMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawCareOptionsValue VARCHAR(255) NOT NULL UNIQUE,
    CareOptionsID INT NOT NULL,
    CONSTRAINT FK_LKP_CareOptions_Map FOREIGN KEY (CareOptionsID)
        REFERENCES dbo.LKP_CareOptions(CareOptionsID)
);
GO

CREATE TABLE dbo.LKP_WellnessProgram_Map
(
    WellnessProgramMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawWellnessProgramValue VARCHAR(255) NOT NULL UNIQUE,
    WellnessProgramID INT NOT NULL,
    CONSTRAINT FK_LKP_WellnessProgram_Map FOREIGN KEY (WellnessProgramID)
        REFERENCES dbo.LKP_WellnessProgram(WellnessProgramID)
);
GO

CREATE TABLE dbo.LKP_AwarenessLevel_Map
(
    AwarenessLevelMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawAwarenessLevelValue VARCHAR(255) NOT NULL UNIQUE,
    AwarenessLevelID INT NOT NULL,
    CONSTRAINT FK_LKP_AwarenessLevel_Map FOREIGN KEY (AwarenessLevelID)
        REFERENCES dbo.LKP_AwarenessLevel(AwarenessLevelID)
);
GO

CREATE TABLE dbo.LKP_KnowledgeLevel_Map
(
    KnowledgeLevelMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawKnowledgeLevelValue VARCHAR(255) NOT NULL UNIQUE,
    KnowledgeLevelID INT NOT NULL,
    CONSTRAINT FK_LKP_KnowledgeLevel_Map FOREIGN KEY (KnowledgeLevelID)
        REFERENCES dbo.LKP_KnowledgeLevel(KnowledgeLevelID)
);
GO

CREATE TABLE dbo.LKP_ComfortLevel_Map
(
    ComfortLevelMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawComfortLevelValue VARCHAR(255) NOT NULL UNIQUE,
    ComfortLevelID INT NOT NULL,
    CONSTRAINT FK_LKP_ComfortLevel_Map FOREIGN KEY (ComfortLevelID)
        REFERENCES dbo.LKP_ComfortLevel(ComfortLevelID)
);
GO

CREATE TABLE dbo.LKP_ManagerSupport_Map
(
    ManagerSupportMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    RawManagerSupportValue VARCHAR(255) NOT NULL UNIQUE,
    ManagerSupportID INT NOT NULL,
    CONSTRAINT FK_LKP_ManagerSupport_Map FOREIGN KEY (ManagerSupportID)
        REFERENCES dbo.LKP_ManagerSupport(ManagerSupportID)
);
GO

/*========================================================
STEP 7: INSERT MASTER LOOKUP VALUES
========================================================*/
INSERT INTO dbo.LKP_Country (CountryName)
VALUES
('Not Found'),
('United States'),
('Canada'),
('United Kingdom');
GO

INSERT INTO dbo.LKP_State (StateCode, StateName, CountryID)
SELECT NULL, 'Not Found', CountryID
FROM dbo.LKP_Country
WHERE CountryName = 'Not Found';
GO

INSERT INTO dbo.LKP_State (StateCode, StateName, CountryID)
SELECT v.StateCode, v.StateName, c.CountryID
FROM (VALUES
    (1 , 'Alabama'),
    (2 , 'Alaska'),
    (4 , 'Arizona'),
    (5 , 'Arkansas'),
    (6 , 'California'),
    (8 , 'Colorado'),
    (9 , 'Connecticut'),
    (10, 'Delaware'),
    (11, 'District of Columbia'),
    (12, 'Florida'),
    (13, 'Georgia'),
    (15, 'Hawaii'),
    (16, 'Idaho'),
    (17, 'Illinois'),
    (18, 'Indiana'),
    (19, 'Iowa'),
    (20, 'Kansas'),
    (21, 'Kentucky'),
    (22, 'Louisiana'),
    (23, 'Maine'),
    (24, 'Maryland'),
    (25, 'Massachusetts'),
    (26, 'Michigan'),
    (27, 'Minnesota'),
    (28, 'Mississippi'),
    (29, 'Missouri'),
    (30, 'Montana'),
    (31, 'Nebraska'),
    (32, 'Nevada'),
    (33, 'New Hampshire'),
    (34, 'New Jersey'),
    (35, 'New Mexico'),
    (36, 'New York'),
    (37, 'North Carolina'),
    (38, 'North Dakota'),
    (39, 'Ohio'),
    (40, 'Oklahoma'),
    (41, 'Oregon'),
    (42, 'Pennsylvania'),
    (44, 'Rhode Island'),
    (45, 'South Carolina'),
    (46, 'South Dakota'),
    (48, 'Texas'),
    (49, 'Utah'),
    (50, 'Vermont'),
    (51, 'Virginia'),
    (53, 'Washington'),
    (54, 'West Virginia'),
    (55, 'Wisconsin'),
    (56, 'Wyoming'),
    (66, 'Guam'),
    (72, 'Puerto Rico'),
    (78, 'Virgin Islands'),
    (NULL, 'IL'),
    (NULL, 'TN'),
    (NULL, 'TX')
) v(StateCode, StateName)
CROSS JOIN dbo.LKP_Country c
WHERE c.CountryName = 'United States';
GO

INSERT INTO dbo.LKP_Gender (GenderCode, GenderValue)
VALUES
(NULL, 'Not Found'),
('1', 'Male'),
('2', 'Female');
GO

INSERT INTO dbo.LKP_AgeGroup (AgeGroupCode, AgeGroupValue)
VALUES
(NULL, 'Not Found'),
('1', '18-24'),
('2', '25-34'),
('3', '35-44'),
('4', '45-54'),
('5', '55-64'),
('6', '65+');
GO

INSERT INTO dbo.LKP_Education (EducationCode, EducationValue)
VALUES
(NULL, 'Not Found'),
('1', 'Never attended school or only kindergarten'),
('2', 'Grades 1 through 8 (Elementary)'),
('3', 'Grades 9 through 11 (Some high school)'),
('4', 'Grade 12 or GED (High school graduate)'),
('5', 'College 1 year to 3 years (Some college or technical school)'),
('6', 'College 4 years or more (College graduate)'),
('9', 'Refused'),
('BLANK', 'Not asked or Missing');
GO

INSERT INTO dbo.LKP_IncomeLevel (IncomeLevelCode, IncomeLevelValue)
VALUES
(NULL, 'Not Found'),
('1',  'Less than $10,000'),
('2',  'Less than $15,000 ($10,000 to < $15,000)'),
('3',  'Less than $20,000 ($15,000 to < $20,000)'),
('4',  'Less than $25,000 ($20,000 to < $25,000)'),
('5',  'Less than $35,000 ($25,000 to < $35,000)'),
('6',  'Less than $50,000 ($35,000 to < $50,000)'),
('7',  'Less than $75,000 ($50,000 to < $75,000)'),
('8',  'Less than $100,000 ($75,000 to < $100,000)'),
('9',  'Less than $150,000 ($100,000 to < $150,000)'),
('10', 'Less than $200,000 ($150,000 to < $200,000)'),
('11', '$200,000 or more'),
('77', 'Dont know/Not sure'),
('99', 'Refused'),
('BLANK', 'Not asked or Missing');
GO

INSERT INTO dbo.LKP_MentalHealthDays (MentalHealthDaysCode, MentalHealthDaysValue)
VALUES
(NULL, 'Not Found'),
('0', '0'),
('1', '1'),
('2', '2'),
('3', '3'),
('4', '4'),
('5', '5'),
('6', '6'),
('7', '7'),
('8', '8'),
('9', '9'),
('10', '10'),
('11', '11'),
('12', '12'),
('13', '13'),
('14', '14'),
('15', '15'),
('16', '16'),
('17', '17'),
('18', '18'),
('19', '19'),
('20', '20'),
('21', '21'),
('22', '22'),
('23', '23'),
('24', '24'),
('25', '25'),
('26', '26'),
('27', '27'),
('28', '28'),
('29', '29'),
('30', '30'),
('77', 'Dont know/Not sure'),
('88', 'None'),
('99', 'Refused'),
('BLANK', 'Not asked or Missing');
GO

INSERT INTO dbo.LKP_GeneralHealthStatus (GeneralHealthStatusCode, GeneralHealthStatusValue)
VALUES
(NULL, 'Not Found'),
('1', 'Excellent'),
('2', 'Very good'),
('3', 'Good'),
('4', 'Fair'),
('5', 'Poor'),
('7', 'Dont know/Not sure'),
('9', 'Refused'),
('BLANK', 'Not asked or Missing');
GO

INSERT INTO dbo.LKP_SmokingStatus (SmokingStatusCode, SmokingStatusValue)
VALUES
(NULL, 'Not Found'),
('1', 'Yes'),
('2', 'No'),
('7', 'Dont know/Not sure'),
('9', 'Refused'),
('BLANK', 'Not asked or Missing'),
('AI1', 'Smoker'),
('AI2', 'Former Smoker'),
('AI3', 'Non-Smoker');
GO

INSERT INTO dbo.LKP_ExerciseStatus (ExerciseStatusCode, ExerciseStatusValue)
VALUES
(NULL, 'Not Found'),
('1', 'Yes'),
('2', 'No'),
('7', 'Dont know/Not sure'),
('9', 'Refused'),
('BLANK', 'Not asked or Missing'),
('AI1', 'Active'),
('AI2', 'Moderate'),
('AI3', 'Inactive');
GO

INSERT INTO dbo.LKP_CheckUpStatus (CheckUpStatusCode, CheckUpStatusValue)
VALUES
(NULL, 'Not Found'),
('1', 'Within past year'),
('2', 'Within past 2 years'),
('3', 'Within past 5 years'),
('4', '5 or more years ago'),
('7', 'Dont know/Not sure'),
('8', 'Never'),
('9', 'Refused'),
('BLANK', 'Not asked or Missing');
GO

INSERT INTO dbo.LKP_FamilyHistory (FamilyHistoryValue)
VALUES
('Not Found'),
('Yes'),
('No');
GO

INSERT INTO dbo.LKP_WorkInterference (WorkInterferenceValue)
VALUES
('Not Found'),
('Often'),
('Sometimes'),
('Rarely'),
('Never');
GO

INSERT INTO dbo.LKP_RemoteWork (RemoteWorkValue)
VALUES
('Not Found'),
('Yes'),
('No');
GO

INSERT INTO dbo.LKP_Benefits (BenefitsValue)
VALUES
('Not Found'),
('Yes'),
('No'),
('Dont know');
GO

INSERT INTO dbo.LKP_SeekHelp (SeekHelpValue)
VALUES
('Not Found'),
('Yes'),
('No'),
('Dont know');
GO

INSERT INTO dbo.LKP_Treatment (TreatmentValue, TreatmentBinaryFlag)
VALUES
('Not Found', 0),
('Yes', 1),
('No', 0);
GO

INSERT INTO dbo.LKP_NumEmployees (NumEmployeesValue)
VALUES
('Not Found'),
('6-25'),
('26-100'),
('100-500'),
('More than 1000');
GO

INSERT INTO dbo.LKP_TechCompany (TechCompanyValue)
VALUES
('Not Found'),
('Yes'),
('No');
GO

INSERT INTO dbo.LKP_CareOptions (CareOptionsValue)
VALUES
('Not Found'),
('Yes'),
('No'),
('Not sure');
GO

INSERT INTO dbo.LKP_WellnessProgram (WellnessProgramValue)
VALUES
('Not Found'),
('Yes'),
('No'),
('Dont know');
GO

INSERT INTO dbo.LKP_AwarenessLevel (AwarenessLevelValue)
VALUES
('Not Found'),
('High'),
('Medium'),
('Low');
GO

INSERT INTO dbo.LKP_KnowledgeLevel (KnowledgeLevelValue)
VALUES
('Not Found'),
('High'),
('Medium'),
('Low');
GO

INSERT INTO dbo.LKP_ComfortLevel (ComfortLevelValue)
VALUES
('Not Found'),
('High'),
('Medium'),
('Low');
GO

INSERT INTO dbo.LKP_ManagerSupport (ManagerSupportValue)
VALUES
('Not Found'),
('High'),
('Medium'),
('Low');
GO

/*========================================================
STEP 8: INSERT MAP VALUES
========================================================*/

/*--------------------------------------------------------
COUNTRY MAP
--------------------------------------------------------*/
;WITH CountrySeed AS
(
    SELECT 'United States' AS RawValue, 'United States' AS FinalCountry
    UNION ALL SELECT 'USA', 'United States'
    UNION ALL SELECT 'US', 'United States'
    UNION ALL SELECT 'U.S.A.', 'United States'
    UNION ALL SELECT 'U.S.', 'United States'
    UNION ALL SELECT 'America', 'United States'
    UNION ALL SELECT 'Canada', 'Canada'
    UNION ALL SELECT 'United Kingdom', 'United Kingdom'
    UNION ALL SELECT 'UK', 'United Kingdom'
    UNION ALL SELECT 'England', 'United Kingdom'
    UNION ALL SELECT 'Great Britain', 'United Kingdom'
    UNION ALL SELECT 'Not Found', 'Not Found'
    UNION ALL SELECT '', 'Not Found'
    UNION ALL SELECT NULL, 'Not Found'
),
CountryNormalized AS
(
    SELECT DISTINCT
        dbo.fn_NormalizeCountryValue(RawValue) AS RawCountryValue,
        FinalCountry
    FROM CountrySeed
)
INSERT INTO dbo.LKP_Country_Map (RawCountryValue, CountryID)
SELECT
    cn.RawCountryValue,
    c.CountryID
FROM CountryNormalized cn
INNER JOIN dbo.LKP_Country c
    ON c.CountryName = cn.FinalCountry
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.LKP_Country_Map x
    WHERE x.RawCountryValue = cn.RawCountryValue
);
GO

/*--------------------------------------------------------
STATE MAP
--------------------------------------------------------*/
;WITH StateSeed AS
(
    SELECT 'Illinois' AS RawStateValue, 'United States' AS CountryName, 'Illinois' AS FinalState
    UNION ALL SELECT 'IL', 'United States', 'IL'
    UNION ALL SELECT 'Tennessee', 'United States', 'Tennessee'
    UNION ALL SELECT 'TN', 'United States', 'TN'
    UNION ALL SELECT 'Texas', 'United States', 'Texas'
    UNION ALL SELECT 'TX', 'United States', 'TX'
    UNION ALL SELECT 'California', 'United States', 'California'
    UNION ALL SELECT 'CA', 'United States', 'California'
    UNION ALL SELECT 'New York', 'United States', 'New York'
    UNION ALL SELECT 'NY', 'United States', 'New York'
    UNION ALL SELECT 'Connecticut', 'United States', 'Connecticut'
    UNION ALL SELECT 'CT', 'United States', 'Connecticut'
    UNION ALL SELECT 'Massachusetts', 'United States', 'Massachusetts'
    UNION ALL SELECT 'MA', 'United States', 'Massachusetts'
    UNION ALL SELECT 'Not Found', 'Not Found', 'Not Found'
    UNION ALL SELECT '', 'Not Found', 'Not Found'
    UNION ALL SELECT NULL, 'Not Found', 'Not Found'
),
StateNormalized AS
(
    SELECT DISTINCT
        dbo.fn_NormalizeLookupValue(RawStateValue) AS RawStateValue,
        CountryName,
        FinalState
    FROM StateSeed
)
INSERT INTO dbo.LKP_State_Map (RawStateValue, CountryID, StateID)
SELECT
    sn.RawStateValue,
    c.CountryID,
    s.StateID
FROM StateNormalized sn
INNER JOIN dbo.LKP_Country c
    ON c.CountryName = sn.CountryName
INNER JOIN dbo.LKP_State s
    ON s.CountryID = c.CountryID
   AND s.StateName = sn.FinalState
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.LKP_State_Map x
    WHERE x.RawStateValue = sn.RawStateValue
      AND x.CountryID = c.CountryID
);
GO

/*--------------------------------------------------------
GENDER MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_Gender_Map (RawGenderValue, GenderID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), g.GenderID
FROM (VALUES
    ('1', 'Male'),
    ('M', 'Male'),
    ('Male', 'Male'),
    (' male ', 'Male'),
    ('2', 'Female'),
    ('F', 'Female'),
    ('Female', 'Female'),
    (' female ', 'Female'),
    ('', 'Not Found'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_Gender g
    ON g.GenderValue = v.FinalValue;
GO

/*--------------------------------------------------------
AGE GROUP MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_AgeGroup_Map (RawAgeGroupValue, AgeGroupID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), a.AgeGroupID
FROM (VALUES
    ('1', '18-24'),
    ('18-24', '18-24'),
    ('Age 18 to 24', '18-24'),
    ('2', '25-34'),
    ('25-34', '25-34'),
    ('Age 25 to 34', '25-34'),
    ('3', '35-44'),
    ('35-44', '35-44'),
    ('Age 35 to 44', '35-44'),
    ('4', '45-54'),
    ('45-54', '45-54'),
    ('Age 45 to 54', '45-54'),
    ('5', '55-64'),
    ('55-64', '55-64'),
    ('Age 55 to 64', '55-64'),
    ('6', '65+'),
    ('65+', '65+'),
    ('65 or older', '65+'),
    ('65 and over', '65+'),
    ('Age 65 or older', '65+'),
    ('', 'Not Found'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_AgeGroup a
    ON a.AgeGroupValue = v.FinalValue;
GO

/*--------------------------------------------------------
EDUCATION MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_Education_Map (RawEducationValue, EducationID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), e.EducationID
FROM (VALUES
    ('1', 'Never attended school or only kindergarten'),
    ('2', 'Grades 1 through 8 (Elementary)'),
    ('3', 'Grades 9 through 11 (Some high school)'),
    ('4', 'Grade 12 or GED (High school graduate)'),
    ('5', 'College 1 year to 3 years (Some college or technical school)'),
    ('6', 'College 4 years or more (College graduate)'),
    ('9', 'Refused'),
    ('BLANK', 'Not asked or Missing'),
    ('', 'Not asked or Missing'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_Education e
    ON e.EducationValue = v.FinalValue;
GO

/*--------------------------------------------------------
INCOME LEVEL MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_IncomeLevel_Map (RawIncomeLevelValue, IncomeLevelID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), i.IncomeLevelID
FROM (VALUES
    ('1', 'Less than $10,000'),
    ('2', 'Less than $15,000 ($10,000 to < $15,000)'),
    ('3', 'Less than $20,000 ($15,000 to < $20,000)'),
    ('4', 'Less than $25,000 ($20,000 to < $25,000)'),
    ('5', 'Less than $35,000 ($25,000 to < $35,000)'),
    ('6', 'Less than $50,000 ($35,000 to < $50,000)'),
    ('7', 'Less than $75,000 ($50,000 to < $75,000)'),
    ('8', 'Less than $100,000 ($75,000 to < $100,000)'),
    ('9', 'Less than $150,000 ($100,000 to < $150,000)'),
    ('10', 'Less than $200,000 ($150,000 to < $200,000)'),
    ('11', '$200,000 or more'),
    ('77', 'Dont know/Not sure'),
    ('99', 'Refused'),
    ('BLANK', 'Not asked or Missing'),
    ('', 'Not asked or Missing'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_IncomeLevel i
    ON i.IncomeLevelValue = v.FinalValue;
GO

/*--------------------------------------------------------
MENTAL HEALTH DAYS MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_MentalHealthDays_Map (RawMentalHealthDaysValue, MentalHealthDaysID)
SELECT DISTINCT dbo.fn_NormalizeMentalHealthDaysValue(v.RawValue), m.MentalHealthDaysID
FROM (VALUES
    ('0', '0'),
    ('1', '1'),
    ('2', '2'),
    ('3', '3'),
    ('4', '4'),
    ('5', '5'),
    ('6', '6'),
    ('7', '7'),
    ('8', '8'),
    ('9', '9'),
    ('10', '10'),
    ('11', '11'),
    ('12', '12'),
    ('13', '13'),
    ('14', '14'),
    ('15', '15'),
    ('16', '16'),
    ('17', '17'),
    ('18', '18'),
    ('19', '19'),
    ('20', '20'),
    ('21', '21'),
    ('22', '22'),
    ('23', '23'),
    ('24', '24'),
    ('25', '25'),
    ('26', '26'),
    ('27', '27'),
    ('28', '28'),
    ('29', '29'),
    ('30', '30'),
    ('None', '0'),
    ('No days', '0'),
    ('77', 'Dont know/Not sure'),
    ('88', 'None'),
    ('99', 'Refused'),
    ('BLANK', 'Not asked or Missing'),
    ('', 'Not asked or Missing'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_MentalHealthDays m
    ON m.MentalHealthDaysValue = v.FinalValue;
GO

/*--------------------------------------------------------
GENERAL HEALTH STATUS MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_GeneralHealthStatus_Map (RawGeneralHealthStatusValue, GeneralHealthStatusID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), g.GeneralHealthStatusID
FROM (VALUES
    ('1', 'Excellent'),
    ('Excellent', 'Excellent'),
    ('2', 'Very good'),
    ('Very good', 'Very good'),
    ('3', 'Good'),
    ('Good', 'Good'),
    ('4', 'Fair'),
    ('Fair', 'Fair'),
    ('5', 'Poor'),
    ('Poor', 'Poor'),
    ('7', 'Dont know/Not sure'),
    ('9', 'Refused'),
    ('BLANK', 'Not asked or Missing'),
    ('', 'Not asked or Missing'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_GeneralHealthStatus g
    ON g.GeneralHealthStatusValue = v.FinalValue;
GO

/*--------------------------------------------------------
SMOKING STATUS MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_SmokingStatus_Map (RawSmokingStatusValue, SmokingStatusID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), s.SmokingStatusID
FROM (VALUES
    ('1', 'Yes'),
    ('Yes', 'Yes'),
    ('Y', 'Yes'),
    ('true', 'Yes'),
    ('2', 'No'),
    ('No', 'No'),
    ('N', 'No'),
    ('false', 'No'),
    ('Smoker', 'Smoker'),
    (' smoker ', 'Smoker'),
    ('Former Smoker', 'Former Smoker'),
    ('Former smoker', 'Former Smoker'),
    ('Ex-smoker', 'Former Smoker'),
    ('Ex smoker', 'Former Smoker'),
    ('Non-Smoker', 'Non-Smoker'),
    ('Non Smoker', 'Non-Smoker'),
    ('Nonsmoker', 'Non-Smoker'),
    ('Never Smoked', 'Non-Smoker'),
    ('7', 'Dont know/Not sure'),
    ('9', 'Refused'),
    ('BLANK', 'Not asked or Missing'),
    ('', 'Not asked or Missing'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_SmokingStatus s
    ON s.SmokingStatusValue = v.FinalValue;
GO

/*--------------------------------------------------------
EXERCISE STATUS MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_ExerciseStatus_Map (RawExerciseStatusValue, ExerciseStatusID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), e.ExerciseStatusID
FROM (VALUES
    ('1', 'Yes'),
    ('Yes', 'Yes'),
    ('Y', 'Yes'),
    ('true', 'Yes'),
    ('2', 'No'),
    ('No', 'No'),
    ('N', 'No'),
    ('false', 'No'),
    ('Active', 'Active'),
    (' active ', 'Active'),
    ('Moderate', 'Moderate'),
    ('Moderately Active', 'Moderate'),
    ('Inactive', 'Inactive'),
    ('Not Active', 'Inactive'),
    ('Sedentary', 'Inactive'),
    ('7', 'Dont know/Not sure'),
    ('9', 'Refused'),
    ('BLANK', 'Not asked or Missing'),
    ('', 'Not asked or Missing'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_ExerciseStatus e
    ON e.ExerciseStatusValue = v.FinalValue;
GO

/*--------------------------------------------------------
YES / NO STYLE MAPS
--------------------------------------------------------*/
INSERT INTO dbo.LKP_RemoteWork_Map (RawRemoteWorkValue, RemoteWorkID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), r.RemoteWorkID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'), ('1', 'Yes'), ('true', 'Yes'),
    ('No', 'No'), ('N', 'No'), ('0', 'No'), ('false', 'No'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_RemoteWork r
    ON r.RemoteWorkValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_TechCompany_Map (RawTechCompanyValue, TechCompanyID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), t.TechCompanyID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'), ('1', 'Yes'), ('true', 'Yes'),
    ('No', 'No'), ('N', 'No'), ('0', 'No'), ('false', 'No'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_TechCompany t
    ON t.TechCompanyValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_Treatment_Map (RawTreatmentValue, TreatmentID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), t.TreatmentID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'), ('1', 'Yes'), ('true', 'Yes'), ('YES', 'Yes'),
    ('No', 'No'), ('N', 'No'), ('0', 'No'), ('false', 'No'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_Treatment t
    ON t.TreatmentValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_FamilyHistory_Map (RawFamilyHistoryValue, FamilyHistoryID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), f.FamilyHistoryID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'), ('1', 'Yes'), ('true', 'Yes'),
    ('No', 'No'), ('N', 'No'), ('0', 'No'), ('false', 'No'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_FamilyHistory f
    ON f.FamilyHistoryValue = v.FinalValue;
GO

/*--------------------------------------------------------
CHECKUP STATUS MAP
--------------------------------------------------------*/
INSERT INTO dbo.LKP_CheckUpStatus_Map (RawCheckUpStatusValue, CheckUpStatusID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), c.CheckUpStatusID
FROM (VALUES
    ('1', 'Within past year'),
    ('Within past year', 'Within past year'),
    ('Within past year anytime less than 12 months ago', 'Within past year'),
    ('2', 'Within past 2 years'),
    ('Within past 2 years', 'Within past 2 years'),
    ('3', 'Within past 5 years'),
    ('Within past 5 years', 'Within past 5 years'),
    ('4', '5 or more years ago'),
    ('5 or more years ago', '5 or more years ago'),
    ('7', 'Dont know/Not sure'),
    ('8', 'Never'),
    ('9', 'Refused'),
    ('BLANK', 'Not asked or Missing'),
    ('', 'Not asked or Missing'),
    ('Not Found', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_CheckUpStatus c
    ON c.CheckUpStatusValue = v.FinalValue;
GO

/*--------------------------------------------------------
WORKPLACE / SUPPORT STYLE MAPS
--------------------------------------------------------*/
INSERT INTO dbo.LKP_Benefits_Map (RawBenefitsValue, BenefitsID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), b.BenefitsID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'), ('1', 'Yes'),
    ('No', 'No'), ('N', 'No'), ('0', 'No'),
    ('Dont know', 'Dont know'), ('Don''t know', 'Dont know'), ('Not sure', 'Dont know'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_Benefits b
    ON b.BenefitsValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_SeekHelp_Map (RawSeekHelpValue, SeekHelpID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), s.SeekHelpID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'), ('1', 'Yes'),
    ('No', 'No'), ('N', 'No'), ('0', 'No'),
    ('Dont know', 'Dont know'), ('Don''t know', 'Dont know'), ('Not sure', 'Dont know'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_SeekHelp s
    ON s.SeekHelpValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_CareOptions_Map (RawCareOptionsValue, CareOptionsID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), c.CareOptionsID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'),
    ('No', 'No'), ('N', 'No'),
    ('Not sure', 'Not sure'), ('Unsure', 'Not sure'), ('Don''t know', 'Not sure'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_CareOptions c
    ON c.CareOptionsValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_WellnessProgram_Map (RawWellnessProgramValue, WellnessProgramID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), w.WellnessProgramID
FROM (VALUES
    ('Yes', 'Yes'), ('Y', 'Yes'),
    ('No', 'No'), ('N', 'No'),
    ('Dont know', 'Dont know'), ('Don''t know', 'Dont know'), ('Not sure', 'Dont know'),
    ('Not Found', 'Not Found'), ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_WellnessProgram w
    ON w.WellnessProgramValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_WorkInterference_Map (RawWorkInterferenceValue, WorkInterferenceID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), w.WorkInterferenceID
FROM (VALUES
    ('Often', 'Often'),
    ('Sometimes', 'Sometimes'),
    ('Rarely', 'Rarely'),
    ('Never', 'Never'),
    ('Not Found', 'Not Found'),
    ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_WorkInterference w
    ON w.WorkInterferenceValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_NumEmployees_Map (RawNumEmployeesValue, NumEmployeesID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), n.NumEmployeesID
FROM (VALUES
    ('6-25', '6-25'),
    ('6 to 25', '6-25'),
    ('26-100', '26-100'),
    ('26 to 100', '26-100'),
    ('100-500', '100-500'),
    ('100 to 500', '100-500'),
    ('More than 1000', 'More than 1000'),
    ('1000+', 'More than 1000'),
    ('Over 1000', 'More than 1000'),
    ('Not Found', 'Not Found'),
    ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_NumEmployees n
    ON n.NumEmployeesValue = v.FinalValue;
GO

/*--------------------------------------------------------
AI LEVEL MAPS
--------------------------------------------------------*/
INSERT INTO dbo.LKP_AwarenessLevel_Map (RawAwarenessLevelValue, AwarenessLevelID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), a.AwarenessLevelID
FROM (VALUES
    ('High', 'High'),
    ('Medium', 'Medium'),
    ('Low', 'Low'),
    ('Not Found', 'Not Found'),
    ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_AwarenessLevel a
    ON a.AwarenessLevelValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_KnowledgeLevel_Map (RawKnowledgeLevelValue, KnowledgeLevelID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), k.KnowledgeLevelID
FROM (VALUES
    ('High', 'High'),
    ('Medium', 'Medium'),
    ('Low', 'Low'),
    ('Not Found', 'Not Found'),
    ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_KnowledgeLevel k
    ON k.KnowledgeLevelValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_ComfortLevel_Map (RawComfortLevelValue, ComfortLevelID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), c.ComfortLevelID
FROM (VALUES
    ('High', 'High'),
    ('Medium', 'Medium'),
    ('Low', 'Low'),
    ('Not Found', 'Not Found'),
    ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_ComfortLevel c
    ON c.ComfortLevelValue = v.FinalValue;
GO

INSERT INTO dbo.LKP_ManagerSupport_Map (RawManagerSupportValue, ManagerSupportID)
SELECT DISTINCT dbo.fn_NormalizeLookupValue(v.RawValue), m.ManagerSupportID
FROM (VALUES
    ('High', 'High'),
    ('Medium', 'Medium'),
    ('Low', 'Low'),
    ('Not Found', 'Not Found'),
    ('', 'Not Found')
) v(RawValue, FinalValue)
JOIN dbo.LKP_ManagerSupport m
    ON m.ManagerSupportValue = v.FinalValue;
GO

/*========================================================
STEP 9: CREATE INDEXES
Indexes help joins from transformed data into lookups
========================================================*/
CREATE NONCLUSTERED INDEX IX_LKP_State_StateCountry
ON dbo.LKP_State (StateName, CountryID);
GO

CREATE NONCLUSTERED INDEX IX_LKP_State_StateCode
ON dbo.LKP_State (StateCode);
GO

CREATE NONCLUSTERED INDEX IX_LKP_State_CountryID
ON dbo.LKP_State (CountryID);
GO

CREATE NONCLUSTERED INDEX IX_LKP_Country_Map_Raw
ON dbo.LKP_Country_Map (RawCountryValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_State_Map_RawCountry
ON dbo.LKP_State_Map (RawStateValue, CountryID);
GO

CREATE NONCLUSTERED INDEX IX_LKP_Gender_Map_Raw
ON dbo.LKP_Gender_Map (RawGenderValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_AgeGroup_Map_Raw
ON dbo.LKP_AgeGroup_Map (RawAgeGroupValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_Education_Map_Raw
ON dbo.LKP_Education_Map (RawEducationValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_IncomeLevel_Map_Raw
ON dbo.LKP_IncomeLevel_Map (RawIncomeLevelValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_MentalHealthDays_Map_Raw
ON dbo.LKP_MentalHealthDays_Map (RawMentalHealthDaysValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_GeneralHealthStatus_Map_Raw
ON dbo.LKP_GeneralHealthStatus_Map (RawGeneralHealthStatusValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_SmokingStatus_Map_Raw
ON dbo.LKP_SmokingStatus_Map (RawSmokingStatusValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_ExerciseStatus_Map_Raw
ON dbo.LKP_ExerciseStatus_Map (RawExerciseStatusValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_CheckUpStatus_Map_Raw
ON dbo.LKP_CheckUpStatus_Map (RawCheckUpStatusValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_FamilyHistory_Map_Raw
ON dbo.LKP_FamilyHistory_Map (RawFamilyHistoryValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_WorkInterference_Map_Raw
ON dbo.LKP_WorkInterference_Map (RawWorkInterferenceValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_RemoteWork_Map_Raw
ON dbo.LKP_RemoteWork_Map (RawRemoteWorkValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_Benefits_Map_Raw
ON dbo.LKP_Benefits_Map (RawBenefitsValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_SeekHelp_Map_Raw
ON dbo.LKP_SeekHelp_Map (RawSeekHelpValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_Treatment_Map_Raw
ON dbo.LKP_Treatment_Map (RawTreatmentValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_NumEmployees_Map_Raw
ON dbo.LKP_NumEmployees_Map (RawNumEmployeesValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_TechCompany_Map_Raw
ON dbo.LKP_TechCompany_Map (RawTechCompanyValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_CareOptions_Map_Raw
ON dbo.LKP_CareOptions_Map (RawCareOptionsValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_WellnessProgram_Map_Raw
ON dbo.LKP_WellnessProgram_Map (RawWellnessProgramValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_AwarenessLevel_Map_Raw
ON dbo.LKP_AwarenessLevel_Map (RawAwarenessLevelValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_KnowledgeLevel_Map_Raw
ON dbo.LKP_KnowledgeLevel_Map (RawKnowledgeLevelValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_ComfortLevel_Map_Raw
ON dbo.LKP_ComfortLevel_Map (RawComfortLevelValue);
GO

CREATE NONCLUSTERED INDEX IX_LKP_ManagerSupport_Map_Raw
ON dbo.LKP_ManagerSupport_Map (RawManagerSupportValue);
GO

/*========================================================
STEP 10: VALIDATION
Keep one clean validation query only
========================================================*/
SELECT 'LKP_Country' AS TableName, COUNT(*) AS TotalRows FROM dbo.LKP_Country
UNION ALL SELECT 'LKP_State', COUNT(*) FROM dbo.LKP_State
UNION ALL SELECT 'LKP_Gender', COUNT(*) FROM dbo.LKP_Gender
UNION ALL SELECT 'LKP_AgeGroup', COUNT(*) FROM dbo.LKP_AgeGroup
UNION ALL SELECT 'LKP_Education', COUNT(*) FROM dbo.LKP_Education
UNION ALL SELECT 'LKP_IncomeLevel', COUNT(*) FROM dbo.LKP_IncomeLevel
UNION ALL SELECT 'LKP_MentalHealthDays', COUNT(*) FROM dbo.LKP_MentalHealthDays
UNION ALL SELECT 'LKP_GeneralHealthStatus', COUNT(*) FROM dbo.LKP_GeneralHealthStatus
UNION ALL SELECT 'LKP_SmokingStatus', COUNT(*) FROM dbo.LKP_SmokingStatus
UNION ALL SELECT 'LKP_ExerciseStatus', COUNT(*) FROM dbo.LKP_ExerciseStatus
UNION ALL SELECT 'LKP_CheckUpStatus', COUNT(*) FROM dbo.LKP_CheckUpStatus
UNION ALL SELECT 'LKP_FamilyHistory', COUNT(*) FROM dbo.LKP_FamilyHistory
UNION ALL SELECT 'LKP_WorkInterference', COUNT(*) FROM dbo.LKP_WorkInterference
UNION ALL SELECT 'LKP_RemoteWork', COUNT(*) FROM dbo.LKP_RemoteWork
UNION ALL SELECT 'LKP_Benefits', COUNT(*) FROM dbo.LKP_Benefits
UNION ALL SELECT 'LKP_SeekHelp', COUNT(*) FROM dbo.LKP_SeekHelp
UNION ALL SELECT 'LKP_Treatment', COUNT(*) FROM dbo.LKP_Treatment
UNION ALL SELECT 'LKP_NumEmployees', COUNT(*) FROM dbo.LKP_NumEmployees
UNION ALL SELECT 'LKP_TechCompany', COUNT(*) FROM dbo.LKP_TechCompany
UNION ALL SELECT 'LKP_CareOptions', COUNT(*) FROM dbo.LKP_CareOptions
UNION ALL SELECT 'LKP_WellnessProgram', COUNT(*) FROM dbo.LKP_WellnessProgram
UNION ALL SELECT 'LKP_AwarenessLevel', COUNT(*) FROM dbo.LKP_AwarenessLevel
UNION ALL SELECT 'LKP_KnowledgeLevel', COUNT(*) FROM dbo.LKP_KnowledgeLevel
UNION ALL SELECT 'LKP_ComfortLevel', COUNT(*) FROM dbo.LKP_ComfortLevel
UNION ALL SELECT 'LKP_ManagerSupport', COUNT(*) FROM dbo.LKP_ManagerSupport
UNION ALL SELECT 'LKP_Country_Map', COUNT(*) FROM dbo.LKP_Country_Map
UNION ALL SELECT 'LKP_State_Map', COUNT(*) FROM dbo.LKP_State_Map
UNION ALL SELECT 'LKP_Gender_Map', COUNT(*) FROM dbo.LKP_Gender_Map
UNION ALL SELECT 'LKP_AgeGroup_Map', COUNT(*) FROM dbo.LKP_AgeGroup_Map
UNION ALL SELECT 'LKP_Education_Map', COUNT(*) FROM dbo.LKP_Education_Map
UNION ALL SELECT 'LKP_IncomeLevel_Map', COUNT(*) FROM dbo.LKP_IncomeLevel_Map
UNION ALL SELECT 'LKP_MentalHealthDays_Map', COUNT(*) FROM dbo.LKP_MentalHealthDays_Map
UNION ALL SELECT 'LKP_GeneralHealthStatus_Map', COUNT(*) FROM dbo.LKP_GeneralHealthStatus_Map
UNION ALL SELECT 'LKP_SmokingStatus_Map', COUNT(*) FROM dbo.LKP_SmokingStatus_Map
UNION ALL SELECT 'LKP_ExerciseStatus_Map', COUNT(*) FROM dbo.LKP_ExerciseStatus_Map
UNION ALL SELECT 'LKP_CheckUpStatus_Map', COUNT(*) FROM dbo.LKP_CheckUpStatus_Map
UNION ALL SELECT 'LKP_FamilyHistory_Map', COUNT(*) FROM dbo.LKP_FamilyHistory_Map
UNION ALL SELECT 'LKP_WorkInterference_Map', COUNT(*) FROM dbo.LKP_WorkInterference_Map
UNION ALL SELECT 'LKP_RemoteWork_Map', COUNT(*) FROM dbo.LKP_RemoteWork_Map
UNION ALL SELECT 'LKP_Benefits_Map', COUNT(*) FROM dbo.LKP_Benefits_Map
UNION ALL SELECT 'LKP_SeekHelp_Map', COUNT(*) FROM dbo.LKP_SeekHelp_Map
UNION ALL SELECT 'LKP_Treatment_Map', COUNT(*) FROM dbo.LKP_Treatment_Map
UNION ALL SELECT 'LKP_NumEmployees_Map', COUNT(*) FROM dbo.LKP_NumEmployees_Map
UNION ALL SELECT 'LKP_TechCompany_Map', COUNT(*) FROM dbo.LKP_TechCompany_Map
UNION ALL SELECT 'LKP_CareOptions_Map', COUNT(*) FROM dbo.LKP_CareOptions_Map
UNION ALL SELECT 'LKP_WellnessProgram_Map', COUNT(*) FROM dbo.LKP_WellnessProgram_Map
UNION ALL SELECT 'LKP_AwarenessLevel_Map', COUNT(*) FROM dbo.LKP_AwarenessLevel_Map
UNION ALL SELECT 'LKP_KnowledgeLevel_Map', COUNT(*) FROM dbo.LKP_KnowledgeLevel_Map
UNION ALL SELECT 'LKP_ComfortLevel_Map', COUNT(*) FROM dbo.LKP_ComfortLevel_Map
UNION ALL SELECT 'LKP_ManagerSupport_Map', COUNT(*) FROM dbo.LKP_ManagerSupport_Map;
GO

PRINT 'Lookup tables and mapping tables created successfully.';
GO
