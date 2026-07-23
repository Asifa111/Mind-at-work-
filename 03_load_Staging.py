import time
from pathlib import Path

import pandas as pd
import pyodbc


# =========================================================
# 03_load_staging.py
# Purpose:
# - Load raw CSV files into staging tables
# - Clean basic text / numeric / date values
# - Match the updated 02_create_tables.sql structure
# - Keep the script simple and easy to follow
# =========================================================


# =========================================================
# DATABASE CONNECTION
# Update these values if your server / database changes
# =========================================================
SERVER = "courseproject-server.database.windows.net"
DATABASE = "us_national_statistics"
USERNAME = "sqladmin"
PASSWORD = "Course@2026!"

CONN_STR = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    f"UID={USERNAME};"
    f"PWD={PASSWORD};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Connection Timeout=60;"
)


# =========================================================
# INPUT FILE PATHS
# Keep the CSV files in the same folder as this script
# =========================================================
BASE_DIR = Path(".")
MENTALHEALTH_FILE = BASE_DIR / "MentalHealth.csv"
WORKPLACE_FILE = BASE_DIR / "MentalHealthWorkPlace.csv"
AI_FILE = BASE_DIR / "AI.csv"


# =========================================================
# HELPER: CREATE DATABASE CONNECTION
# =========================================================
def create_connection():
    return pyodbc.connect(CONN_STR)


# =========================================================
# HELPER: CHECK INPUT FILE EXISTS
# =========================================================
def validate_input_file(file_path: Path) -> None:
    if not file_path.exists():
        raise FileNotFoundError(f"Input file not found: {file_path}")
    print(f"Found input file: {file_path}")


# =========================================================
# HELPER: CLEAN NORMAL TEXT COLUMNS
# - strips spaces
# - converts blank / nan-like values to None
# =========================================================
def clean_text_column(series: pd.Series) -> pd.Series:
    cleaned = series.astype(str).str.strip()
    cleaned = cleaned.replace(
        {
            "": None,
            "nan": None,
            "NaN": None,
            "None": None,
            "NULL": None,
            "null": None,
            "N/A": None,
            "n/a": None,
        }
    )
    return cleaned


# =========================================================
# HELPER: CLEAN SPECIAL TEXT
# Useful for columns that may look like b'1231'
# =========================================================
def clean_special_text_column(series: pd.Series) -> pd.Series:
    cleaned = (
        series.astype(str)
        .str.replace("b'", "", regex=False)
        .str.replace("'", "", regex=False)
        .str.strip()
    )
    cleaned = cleaned.replace(
        {
            "": None,
            "nan": None,
            "NaN": None,
            "None": None,
            "NULL": None,
            "null": None,
            "N/A": None,
            "n/a": None,
        }
    )
    return cleaned


# =========================================================
# HELPER: NORMALIZE YES / NO STYLE VALUES
# =========================================================
def normalize_yes_no_column(series: pd.Series) -> pd.Series:
    mapping = {
        "yes": "Yes",
        "y": "Yes",
        "true": "Yes",
        "1": "Yes",
        "no": "No",
        "n": "No",
        "false": "No",
        "0": "No",
        "don't know": "Don't know",
        "dont know": "Don't know",
        "maybe": "Maybe",
    }

    cleaned = clean_text_column(series)
    return cleaned.apply(
        lambda x: mapping.get(str(x).strip().lower(), x) if x is not None else None
    )


# =========================================================
# HELPER: SAFE INTEGER CONVERSION
# =========================================================
def to_nullable_int_series(series: pd.Series) -> pd.Series:
    converted = pd.to_numeric(series, errors="coerce")
    return converted.where(pd.notnull(converted), None)


# =========================================================
# HELPER: SAFE DATE CONVERSION
# =========================================================
def to_nullable_date_series(series: pd.Series) -> pd.Series:
    converted = pd.to_datetime(series, errors="coerce")
    return converted.dt.date.where(pd.notnull(converted), None)


# =========================================================
# HELPER: BUILD DATE FROM YEAR + MONTH
# Uses day = 1
# =========================================================
def build_full_date_from_year_month(year_series: pd.Series, month_series: pd.Series) -> pd.Series:
    years = pd.to_numeric(year_series, errors="coerce")
    months = pd.to_numeric(month_series, errors="coerce")

    built = pd.to_datetime(
        {
            "year": years,
            "month": months,
            "day": 1,
        },
        errors="coerce",
    )
    return built.dt.date.where(pd.notnull(built), None)


# =========================================================
# HELPER: FINALIZE DATAFRAME BEFORE SQL INSERT
# Converts pandas NaN to Python None
# =========================================================
def finalize_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    df = df.astype(object)
    df = df.where(pd.notnull(df), None)
    return df


# =========================================================
# HELPER: INSERT DATAFRAME IN SMALL BATCHES
# fast_executemany improves insert speed
# =========================================================
def insert_dataframe_in_batches(
    df: pd.DataFrame,
    table_name: str,
    insert_sql: str,
    batch_size: int = 500,
    max_retries: int = 3,
) -> int:
    total_rows = len(df)

    if total_rows == 0:
        print(f"No rows to insert into {table_name}.")
        return 0

    inserted_rows = 0

    for start in range(0, total_rows, batch_size):
        end = min(start + batch_size, total_rows)
        batch = df.iloc[start:end].copy()
        rows = [tuple(row) for row in batch.itertuples(index=False, name=None)]

        for attempt in range(1, max_retries + 1):
            conn = None
            cursor = None

            try:
                conn = create_connection()
                cursor = conn.cursor()
                cursor.fast_executemany = True
                cursor.executemany(insert_sql, rows)
                conn.commit()

                inserted_rows += len(rows)
                print(f"{inserted_rows} rows inserted into {table_name}")
                break

            except pyodbc.OperationalError as e:
                print(
                    f"\nConnection issue while inserting rows {start + 1} to {end} into {table_name}"
                )
                print(f"Retry {attempt} of {max_retries}")
                print(str(e))

                if attempt == max_retries:
                    print("\nMaximum retries reached.")
                    print("Sample failing batch:")
                    print(batch.head(10))
                    raise

                time.sleep(2)

            except Exception:
                print(f"\nError while inserting rows {start + 1} to {end} into {table_name}")
                print("Sample failing batch:")
                print(batch.head(10))
                raise

            finally:
                if cursor is not None:
                    cursor.close()
                if conn is not None:
                    conn.close()

    return inserted_rows


# =========================================================
# STEP 1: VALIDATE INPUT FILES
# =========================================================
print("\nValidating input files...")
validate_input_file(MENTALHEALTH_FILE)
validate_input_file(WORKPLACE_FILE)
validate_input_file(AI_FILE)
print("All input files found successfully.")


# =========================================================
# STEP 2: TRUNCATE STAGING TABLES
# Load starts fresh each time
# =========================================================
print("\nConnecting to Azure SQL Database...")
conn = create_connection()
cursor = conn.cursor()

truncate_sql = """
TRUNCATE TABLE dbo.AI_Staging;
TRUNCATE TABLE dbo.MentalHealthWorkPlace_Staging;
TRUNCATE TABLE dbo.MentalHealth_Staging;
"""

cursor.execute(truncate_sql)
conn.commit()
cursor.close()
conn.close()

print("All staging tables truncated successfully.")


# =========================================================
# STEP 3: LOAD MentalHealth.csv
# =========================================================
mentalhealth_column_map = {
    "IDATE": "Date",
    "IMONTH": "Month",
    "IDAY": "Day",
    "_STATE": "State",
    "_SEX": "Gender",
    "_AGE_G": "AgeGroup",
    "EDUCA": "Education",
    "INCOME3": "IncomeLevel",
    "MENTHLTH": "MentalHealthDays",
    "GENHLTH": "GeneralHealthStatus",
    "SMOKE100": "SmokingStatus",
    "EXERANY2": "ExerciseStatus",
    "CHECKUP1": "CheckUpStatus",
}

mentalhealth_required_columns = [
    "Date",
    "Month",
    "Day",
    "State",
    "Gender",
    "AgeGroup",
    "Education",
    "IncomeLevel",
    "MentalHealthDays",
    "GeneralHealthStatus",
    "SmokingStatus",
    "ExerciseStatus",
    "CheckUpStatus",
]

mentalhealth_insert_sql = """
INSERT INTO dbo.MentalHealth_Staging
(
    Date,
    Month,
    Day,
    State,
    Gender,
    AgeGroup,
    Education,
    IncomeLevel,
    MentalHealthDays,
    GeneralHealthStatus,
    SmokingStatus,
    ExerciseStatus,
    CheckUpStatus
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

print("\nReading and loading MentalHealth.csv in chunks...")
mentalhealth_total = 0

for chunk_num, chunk in enumerate(pd.read_csv(MENTALHEALTH_FILE, chunksize=5000), start=1):
    available_columns = [col for col in mentalhealth_column_map if col in chunk.columns]
    chunk = chunk[available_columns].rename(
        columns={col: mentalhealth_column_map[col] for col in available_columns}
    )

    for col in mentalhealth_required_columns:
        if col not in chunk.columns:
            chunk[col] = None

    chunk = chunk[mentalhealth_required_columns]

    for col in ["Date", "Month", "Day"]:
        chunk[col] = clean_special_text_column(chunk[col])

    for col in [
        "State",
        "Gender",
        "AgeGroup",
        "Education",
        "IncomeLevel",
        "GeneralHealthStatus",
        "SmokingStatus",
        "ExerciseStatus",
        "CheckUpStatus",
    ]:
        chunk[col] = clean_text_column(chunk[col])

    chunk["MentalHealthDays"] = to_nullable_int_series(chunk["MentalHealthDays"])
    chunk = finalize_dataframe(chunk)

    print(f"\nProcessing MentalHealth.csv chunk {chunk_num}...")
    mentalhealth_total += insert_dataframe_in_batches(
        df=chunk,
        table_name="dbo.MentalHealth_Staging",
        insert_sql=mentalhealth_insert_sql,
        batch_size=500,
    )

print(f"\nFinished loading dbo.MentalHealth_Staging. Total rows inserted: {mentalhealth_total}")


# =========================================================
# STEP 4: LOAD MentalHealthWorkPlace.csv
# This version matches the updated staging table and now
# includes AwarenessLevel, KnowledgeLevel, ComfortLevel,
# and ManagerSupport.
# =========================================================
workplace_column_map = {
    "Age": "Age",
    "Gender": "Gender",
    "Country": "Country",
    "state": "State",
    "family_history": "FamilyHistory",
    "work_interfere": "WorkInterference",
    "remote_work": "RemoteWork",
    "benefits": "Benefits",
    "seek_help": "SeekHelp",
    "treatment": "Treatment",
    "no_employees": "NumEmployees",
    "tech_company": "TechCompany",
    "care_options": "CareOptions",
    "wellness_program": "WellnessProgram",
    "awareness_of_options": "AwarenessLevel",
    "know_resources": "KnowledgeLevel",
    "anonymity_protected": "ComfortLevel",
    "supervisor_support": "ManagerSupport",
}

workplace_required_columns = [
    "Age",
    "Gender",
    "Country",
    "State",
    "FamilyHistory",
    "WorkInterference",
    "RemoteWork",
    "Benefits",
    "SeekHelp",
    "Treatment",
    "NumEmployees",
    "TechCompany",
    "CareOptions",
    "WellnessProgram",
    "AwarenessLevel",
    "KnowledgeLevel",
    "ComfortLevel",
    "ManagerSupport",
]

workplace_insert_sql = """
INSERT INTO dbo.MentalHealthWorkPlace_Staging
(
    Age,
    Gender,
    Country,
    State,
    FamilyHistory,
    WorkInterference,
    RemoteWork,
    Benefits,
    SeekHelp,
    Treatment,
    NumEmployees,
    TechCompany,
    CareOptions,
    WellnessProgram,
    AwarenessLevel,
    KnowledgeLevel,
    ComfortLevel,
    ManagerSupport
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

print("\nReading and loading MentalHealthWorkPlace.csv in chunks...")
workplace_total = 0

for chunk_num, chunk in enumerate(pd.read_csv(WORKPLACE_FILE, chunksize=5000), start=1):
    available_columns = [col for col in workplace_column_map if col in chunk.columns]
    chunk = chunk[available_columns].rename(
        columns={col: workplace_column_map[col] for col in available_columns}
    )

    for col in workplace_required_columns:
        if col not in chunk.columns:
            chunk[col] = None

    chunk = chunk[workplace_required_columns]

    for col in workplace_required_columns:
        chunk[col] = clean_text_column(chunk[col])

    for col in [
        "FamilyHistory",
        "RemoteWork",
        "Benefits",
        "SeekHelp",
        "Treatment",
        "TechCompany",
        "CareOptions",
        "WellnessProgram",
    ]:
        chunk[col] = normalize_yes_no_column(chunk[col])

    chunk = finalize_dataframe(chunk)

    print(f"\nProcessing MentalHealthWorkPlace.csv chunk {chunk_num}...")
    workplace_total += insert_dataframe_in_batches(
        df=chunk,
        table_name="dbo.MentalHealthWorkPlace_Staging",
        insert_sql=workplace_insert_sql,
        batch_size=500,
    )

print(
    f"\nFinished loading dbo.MentalHealthWorkPlace_Staging. Total rows inserted: {workplace_total}"
)


# =========================================================
# STEP 5: LOAD AI.csv
# =========================================================
ai_column_map = {
    "SourcePersonID": "SourcePersonID",
    "Year": "Year",
    "Month": "Month",
    "Gender": "Gender",
    "AgeGroup": "AgeGroup",
    "Education": "Education",
    "IncomeLevel": "IncomeLevel",
    "FamilyHistory": "FamilyHistory",
    "Country": "Country",
    "State": "State",
    "NumEmployees": "NumEmployees",
    "TechCompany": "TechCompany",
    "CareOptions": "CareOptions",
    "WellnessProgram": "WellnessProgram",
    "RemoteWork": "RemoteWork",
    "Benefits": "Benefits",
    "WorkInterference": "WorkInterference",
    "AwarenessLevel": "AwarenessLevel",
    "KnowledgeLevel": "KnowledgeLevel",
    "ComfortLevel": "ComfortLevel",
    "ManagerSupport": "ManagerSupport",
    "MentalHealthDays": "MentalHealthDays",
    "SmokingStatus": "SmokingStatus",
    "ExerciseStatus": "ExerciseStatus",
    "GeneralHealthStatus": "GeneralHealthStatus",
    "SeekHelp": "SeekHelp",
    "Treatment": "Treatment",
    "FullDate": "FullDate",
}

ai_required_columns = [
    "SourcePersonID",
    "Year",
    "Month",
    "Gender",
    "AgeGroup",
    "Education",
    "IncomeLevel",
    "FamilyHistory",
    "Country",
    "State",
    "NumEmployees",
    "TechCompany",
    "CareOptions",
    "WellnessProgram",
    "RemoteWork",
    "Benefits",
    "WorkInterference",
    "AwarenessLevel",
    "KnowledgeLevel",
    "ComfortLevel",
    "ManagerSupport",
    "MentalHealthDays",
    "SmokingStatus",
    "ExerciseStatus",
    "GeneralHealthStatus",
    "SeekHelp",
    "Treatment",
    "FullDate",
]

ai_insert_sql = """
INSERT INTO dbo.AI_Staging
(
    SourcePersonID,
    Year,
    Month,
    Gender,
    AgeGroup,
    Education,
    IncomeLevel,
    FamilyHistory,
    Country,
    State,
    NumEmployees,
    TechCompany,
    CareOptions,
    WellnessProgram,
    RemoteWork,
    Benefits,
    WorkInterference,
    AwarenessLevel,
    KnowledgeLevel,
    ComfortLevel,
    ManagerSupport,
    MentalHealthDays,
    SmokingStatus,
    ExerciseStatus,
    GeneralHealthStatus,
    SeekHelp,
    Treatment,
    FullDate
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

print("\nReading and loading AI.csv in chunks...")
ai_total = 0

for chunk_num, chunk in enumerate(pd.read_csv(AI_FILE, chunksize=5000), start=1):
    available_columns = [col for col in ai_column_map if col in chunk.columns]
    chunk = chunk[available_columns].rename(
        columns={col: ai_column_map[col] for col in available_columns}
    )

    for col in ai_required_columns:
        if col not in chunk.columns:
            chunk[col] = None

    chunk = chunk[ai_required_columns]

    for col in ["SourcePersonID", "Year", "Month", "MentalHealthDays"]:
        chunk[col] = to_nullable_int_series(chunk[col])

    existing_full_date = to_nullable_date_series(chunk["FullDate"])
    derived_full_date = build_full_date_from_year_month(chunk["Year"], chunk["Month"])
    chunk["FullDate"] = pd.Series(existing_full_date).where(pd.notnull(existing_full_date), derived_full_date)

    for col in [
        "Gender",
        "AgeGroup",
        "Education",
        "IncomeLevel",
        "FamilyHistory",
        "Country",
        "State",
        "NumEmployees",
        "TechCompany",
        "CareOptions",
        "WellnessProgram",
        "RemoteWork",
        "Benefits",
        "WorkInterference",
        "AwarenessLevel",
        "KnowledgeLevel",
        "ComfortLevel",
        "ManagerSupport",
        "SmokingStatus",
        "ExerciseStatus",
        "GeneralHealthStatus",
        "SeekHelp",
        "Treatment",
    ]:
        chunk[col] = clean_text_column(chunk[col])

    for col in [
        "FamilyHistory",
        "TechCompany",
        "CareOptions",
        "WellnessProgram",
        "RemoteWork",
        "Benefits",
        "SeekHelp",
        "Treatment",
    ]:
        chunk[col] = normalize_yes_no_column(chunk[col])

    chunk = finalize_dataframe(chunk)

    print(f"\nProcessing AI.csv chunk {chunk_num}...")
    ai_total += insert_dataframe_in_batches(
        df=chunk,
        table_name="dbo.AI_Staging",
        insert_sql=ai_insert_sql,
        batch_size=500,
    )

print(f"\nFinished loading dbo.AI_Staging. Total rows inserted: {ai_total}")


# =========================================================
# STEP 6: FINAL VALIDATION
# Check row counts after loading
# =========================================================
print("\nChecking final row counts in staging tables...")

conn = create_connection()
cursor = conn.cursor()

validation_sql = """
SELECT 'MentalHealth_Staging' AS TableName, COUNT(*) AS TotalRows
FROM dbo.MentalHealth_Staging
UNION ALL
SELECT 'MentalHealthWorkPlace_Staging' AS TableName, COUNT(*) AS TotalRows
FROM dbo.MentalHealthWorkPlace_Staging
UNION ALL
SELECT 'AI_Staging' AS TableName, COUNT(*) AS TotalRows
FROM dbo.AI_Staging;
"""

cursor.execute(validation_sql)
for row in cursor.fetchall():
    print(f"{row.TableName}: {row.TotalRows}")

cursor.close()
conn.close()

print("\nAll staging tables loaded successfully.")
