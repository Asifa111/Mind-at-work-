-- --------------------------------------------------
-- Drop tables if they already exist
-- --------------------------------------------------
IF OBJECT_ID('dbo.MentalHealth_staging', 'U') IS NOT NULL
    DROP TABLE dbo.MentalHealth_staging;
GO

IF OBJECT_ID('dbo.MentalHealthWorkPlace_staging', 'U') IS NOT NULL
    DROP TABLE dbo.MentalHealthWorkPlace_staging;
GO


-- --------------------------------------------------
-- Create MentalHealth_staging
-- --------------------------------------------------
CREATE TABLE dbo.MentalHealth_staging (
    Date      VARCHAR(20),
    Month     VARCHAR(5),
    Day       VARCHAR(5),
    State     INT,
    Gender    INT,
    AgeGroup  INT,
    Education INT,
    IncomeLevel INT,
    MentalHealthDays FLOAT
);
GO


-- --------------------------------------------------
-- Create MentalHealthWorkPlace_staging
-- --------------------------------------------------
CREATE TABLE dbo.MentalHealthWorkPlace_staging (
    Age               INT NULL,
    Gender            VARCHAR(50) NULL,
    Country           VARCHAR(100) NULL,
    State             VARCHAR(50) NULL,
    FamilyHistory     VARCHAR(50) NULL,
    WorkInterference  VARCHAR(50) NULL,
    RemoteWork        VARCHAR(50) NULL,
    Benefits          VARCHAR(50) NULL,
    WellnessProgram   VARCHAR(50) NULL,
    SeekHelp          VARCHAR(50) NULL,
    Treatment         VARCHAR(50) NULL
);
GO

-- --------------------------------------------------
-- Drop lookup tables if they already exist
-- --------------------------------------------------
IF OBJECT_ID('dbo.LKP_State', 'U') IS NOT NULL
    DROP TABLE dbo.LKP_State;
GO

IF OBJECT_ID('dbo.LKP_Gender', 'U') IS NOT NULL
    DROP TABLE dbo.LKP_Gender;
GO

IF OBJECT_ID('dbo.LKP_AgeGroup', 'U') IS NOT NULL
    DROP TABLE dbo.LKP_AgeGroup;
GO
-- --------------------------------------------------
-- Drop additional lookup tables if they already exist
-- --------------------------------------------------
IF OBJECT_ID('dbo.LKP_Education', 'U') IS NOT NULL
    DROP TABLE dbo.LKP_Education;
GO

IF OBJECT_ID('dbo.LKP_IncomeLevel', 'U') IS NOT NULL
    DROP TABLE dbo.LKP_IncomeLevel;
GO

IF OBJECT_ID('dbo.LKP_MentalHealthDays', 'U') IS NOT NULL
    DROP TABLE dbo.LKP_MentalHealthDays;
GO

-- --------------------------------------------------
-- Create State lookup table
-- --------------------------------------------------
CREATE TABLE dbo.LKP_State (
    StateCode INT PRIMARY KEY,
    StateName VARCHAR(100) NOT NULL
);
GO


-- --------------------------------------------------
-- Create Gender lookup table
-- --------------------------------------------------
CREATE TABLE dbo.LKP_Gender (
    GenderCode INT PRIMARY KEY,
    GenderLabel VARCHAR(20) NOT NULL
);
GO


-- --------------------------------------------------
-- Create AgeGroup lookup table
-- --------------------------------------------------
CREATE TABLE dbo.LKP_AgeGroup (
    AgeGroupCode INT PRIMARY KEY,
    AgeGroupLabel VARCHAR(50) NOT NULL
);
GO
----- Load State lookup table
INSERT INTO dbo.LKP_State (StateCode, StateName)
VALUES
(1, 'Alabama'),
(2, 'Alaska'),
(4, 'Arizona'),
(5, 'Arkansas'),
(6, 'California'),
(8, 'Colorado'),
(9, 'Connecticut'),
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
(78, 'Virgin Islands');
GO
-- --------------------------------------------------
-- Create Education lookup table
-- --------------------------------------------------
CREATE TABLE dbo.LKP_Education (
    EducationCode INT PRIMARY KEY,
    EducationLabel VARCHAR(150) NOT NULL
);
GO

-- --------------------------------------------------
-- Create IncomeLevel lookup table
-- --------------------------------------------------
CREATE TABLE dbo.LKP_IncomeLevel (
    IncomeLevelCode INT PRIMARY KEY,
    IncomeLevelLabel VARCHAR(150) NOT NULL
);
GO

-- --------------------------------------------------
-- Create MentalHealthDays lookup table
-- --------------------------------------------------
CREATE TABLE dbo.LKP_MentalHealthDays (
    MentalHealthDaysCode INT PRIMARY KEY,
    MentalHealthDaysLabel VARCHAR(100) NOT NULL
);
GO
----- load gender lookup table
INSERT INTO dbo.LKP_Gender (GenderCode, GenderLabel)
VALUES
(1, 'Male'),
(2, 'Female');
GO
----- load age group lookup table
INSERT INTO dbo.LKP_AgeGroup (AgeGroupCode, AgeGroupLabel)
VALUES
(1, 'Age 18 to 24'),
(2, 'Age 25 to 34'),
(3, 'Age 35 to 44'),
(4, 'Age 45 to 54'),
(5, 'Age 55 to 64'),
(6, 'Age 65 or older');
GO
-- --------------------------------------------------
-- Load Education lookup table
-- --------------------------------------------------
INSERT INTO dbo.LKP_Education (EducationCode, EducationLabel)
VALUES
(1, 'Never attended school or only kindergarten'),
(2, 'Grades 1 through 8 (Elementary)'),
(3, 'Grades 9 through 11 (Some high school)'),
(4, 'Grade 12 or GED (High school graduate)'),
(5, 'College 1 year to 3 years (Some college or technical school)'),
(6, 'College 4 years or more (College graduate)'),
(9, 'Refused');
GO
-- --------------------------------------------------
-- Load IncomeLevel lookup table
-- --------------------------------------------------
INSERT INTO dbo.LKP_IncomeLevel (IncomeLevelCode, IncomeLevelLabel)
VALUES
(1, 'Less than $10,000'),
(2, 'Less than $15,000 ($10,000 to < $15,000)'),
(3, 'Less than $20,000 ($15,000 to < $20,000)'),
(4, 'Less than $25,000 ($20,000 to < $25,000)'),
(5, 'Less than $35,000 ($25,000 to < $35,000)'),
(6, 'Less than $50,000 ($35,000 to < $50,000)'),
(7, 'Less than $75,000 ($50,000 to < $75,000)'),
(8, 'Less than $100,000 ($75,000 to < $100,000)'),
(9, 'Less than $150,000 ($100,000 to < $150,000)'),
(10, 'Less than $200,000 ($150,000 to < $200,000)'),
(11, '$200,000 or more'),
(77, 'Don''t know / Not sure'),
(99, 'Refused');
GO
-- --------------------------------------------------
-- Load MentalHealthDays lookup table for values 1 to 30
-- --------------------------------------------------
WITH Numbers AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM Numbers
    WHERE n < 30
)
INSERT INTO dbo.LKP_MentalHealthDays (MentalHealthDaysCode, MentalHealthDaysLabel)
SELECT
    n,
    CONCAT(CAST(n AS VARCHAR(3)), ' day(s)')
FROM Numbers
OPTION (MAXRECURSION 30);
GO
-- --------------------------------------------------
-- Load special MentalHealthDays codes
-- --------------------------------------------------
INSERT INTO dbo.LKP_MentalHealthDays (MentalHealthDaysCode, MentalHealthDaysLabel)
VALUES
(77, 'Don''t know / Not sure'),
(88, 'None'),
(99, 'Refused');
GO
----- Create transformed table of MentalHealth
-- --------------------------------------------------
-- Drop transformed table if it already exists
-- --------------------------------------------------
IF OBJECT_ID('dbo.MentalHealth_transformed', 'U') IS NOT NULL
    DROP TABLE dbo.MentalHealth_transformed;
GO


-- --------------------------------------------------
-- Create transformed table
-- --------------------------------------------------
-- --------------------------------------------------
-- Drop transformed table if it already exists
-- --------------------------------------------------
IF OBJECT_ID('dbo.MentalHealth_transformed', 'U') IS NOT NULL
    DROP TABLE dbo.MentalHealth_transformed;
GO

-- --------------------------------------------------
-- Create transformed table
-- --------------------------------------------------
CREATE TABLE dbo.MentalHealth_transformed (
    FullDate DATE NULL,
    StateCode INT NULL,
    StateName VARCHAR(100) NULL,
    GenderCode INT NULL,
    GenderLabel VARCHAR(20) NULL,
    AgeGroupCode INT NULL,
    AgeGroupLabel VARCHAR(50) NULL,
    EducationCode INT NULL,
    EducationLabel VARCHAR(150) NULL,
    IncomeLevelCode INT NULL,
    IncomeLevelLabel VARCHAR(150) NULL,
    MentalHealthDaysCode INT NULL,
    MentalHealthDaysLabel VARCHAR(100) NULL
);
GO
-----
-- --------------------------------------------------
-- Transform and load data using lookup tables
-- --------------------------------------------------
-- --------------------------------------------------
-- Transform and load data using lookup tables
-- --------------------------------------------------
INSERT INTO dbo.MentalHealth_transformed (
    FullDate,
    StateCode,
    StateName,
    GenderCode,
    GenderLabel,
    AgeGroupCode,
    AgeGroupLabel,
    EducationCode,
    EducationLabel,
    IncomeLevelCode,
    IncomeLevelLabel,
    MentalHealthDaysCode,
    MentalHealthDaysLabel
)
SELECT
    TRY_CONVERT(DATE,
        STUFF(
            STUFF(m.Date, 3, 0, '/'),
            6, 0, '/'
        ), 101
    ) AS FullDate,
    m.State AS StateCode,
    s.StateName,
    m.Gender AS GenderCode,
    g.GenderLabel,
    m.AgeGroup AS AgeGroupCode,
    a.AgeGroupLabel,
    m.Education AS EducationCode,
    e.EducationLabel,
    m.IncomeLevel AS IncomeLevelCode,
    i.IncomeLevelLabel,
    CAST(m.MentalHealthDays AS INT) AS MentalHealthDaysCode,
    mh.MentalHealthDaysLabel
FROM dbo.MentalHealth_staging m
LEFT JOIN dbo.LKP_State s
    ON m.State = s.StateCode
LEFT JOIN dbo.LKP_Gender g
    ON m.Gender = g.GenderCode
LEFT JOIN dbo.LKP_AgeGroup a
    ON m.AgeGroup = a.AgeGroupCode
LEFT JOIN dbo.LKP_Education e
    ON m.Education = e.EducationCode
LEFT JOIN dbo.LKP_IncomeLevel i
    ON m.IncomeLevel = i.IncomeLevelCode
LEFT JOIN dbo.LKP_MentalHealthDays mh
    ON CAST(m.MentalHealthDays AS INT) = mh.MentalHealthDaysCode;
GO
-- --------------------------------------------------
-- Preview Top 10 Rows
-- --------------------------------------------------
SELECT TOP 10 *
FROM dbo.MentalHealth_staging;
GO

SELECT TOP 10 *
FROM dbo.MentalHealthWorkPlace_staging;
GO


-- --------------------------------------------------
-- Check Total Rows
-- --------------------------------------------------
SELECT COUNT(*) AS TotalRows
FROM dbo.MentalHealth_staging;

SELECT COUNT(*) AS TotalRows
FROM dbo.MentalHealthWorkPlace_staging;
GO
-- --------------------------------------------------
-- Preview transformed data
-- --------------------------------------------------
SELECT TOP 10 *
FROM dbo.MentalHealth_transformed;
GO