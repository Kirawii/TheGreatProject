-- IF DB_ID(N'TGP') IS NOT NULL
--     DROP DATABASE TGP1;
-- GO

-- CREATE DATABASE TGP COLLATE Chinese_PRC_CI_AS;
-- GO
-- USE TGP;
-- GO

-- CREATE TABLE DimTime(
--     date_key DATE PRIMARY KEY,
--     [year] INT NOT NULL,
--     [quarter] TINYINT NOT NULL CHECK([quarter] BETWEEN 1 AND 4),
--     [month] TINYINT NOT NULL CHECK([month] BETWEEN 1 AND 12),
--     year_month AS (
--         CAST([year] AS CHAR(4)) + '-' +
--         RIGHT('0' + CAST([month] AS VARCHAR(2)), 2)
--     ) PERSISTED,
--     month_start BIT NOT NULL DEFAULT 0
-- );

-- CREATE TABLE DimRegion(
--     region_id INT IDENTITY(1,1) PRIMARY KEY,
--     region_name NVARCHAR(100) NOT NULL,
--     region_level TINYINT NOT NULL CHECK(region_level BETWEEN 0 AND 5),
--     parent_region_id INT NULL REFERENCES DimRegion(region_id)
-- );
-- CREATE UNIQUE INDEX UX_DimRegion_Name_Level
--         ON DimRegion(region_name, region_level);

-- CREATE TABLE DimRegionGroup(
--     region_group_id TINYINT PRIMARY KEY,
--     group_name NVARCHAR(20) NOT NULL UNIQUE
-- );

-- CREATE TABLE Bridge_Region_Group(
--     region_id INT NOT NULL REFERENCES DimRegion(region_id),
--     region_group_id TINYINT NOT NULL REFERENCES DimRegionGroup(region_group_id),
--     PRIMARY KEY(region_id, region_group_id)
-- );

-- CREATE TABLE DimCountry(
--     country_id INT IDENTITY(1,1) PRIMARY KEY,
--     country_name NVARCHAR(100) NOT NULL UNIQUE
-- );

-- CREATE TABLE FactGDP(
--     region_id INT NOT NULL REFERENCES DimRegion(region_id),
--     date_key DATE NOT NULL REFERENCES DimTime(date_key),
--     gdp_value DECIMAL(18,2) NOT NULL,
--     PRIMARY KEY(region_id, date_key)
-- );
-- CREATE INDEX IX_FactGDP_DateRegion ON FactGDP(date_key, region_id);

-- CREATE TABLE FactDemographics(
--     region_id INT NOT NULL REFERENCES DimRegion(region_id),
--     date_key DATE NOT NULL REFERENCES DimTime(date_key),
--     population BIGINT NOT NULL,
--     area_km2 DECIMAL(18,2) NULL,
--     PRIMARY KEY(region_id, date_key)
-- );
-- CREATE INDEX IX_Demo_DateRegion ON FactDemographics(date_key, region_id);

-- CREATE TABLE FactTrade(
--     region_id INT NOT NULL REFERENCES DimRegion(region_id),
--     partner_country_id INT NOT NULL REFERENCES DimCountry(country_id),
--     date_key DATE NOT NULL REFERENCES DimTime(date_key),
--     exports_value DECIMAL(18,2) NULL,
--     imports_value DECIMAL(18,2) NULL,
--     PRIMARY KEY(region_id, partner_country_id, date_key)
-- );
-- CREATE INDEX IX_Trade_Date_RegionCountry
--         ON FactTrade(date_key, region_id, partner_country_id);

-- CREATE TABLE Result_PerCapitaGDP_Ranking(
--     analysis_id INT IDENTITY(1,1) PRIMARY KEY,
--     region_id INT NOT NULL REFERENCES DimRegion(region_id),
--     date_key DATE NOT NULL REFERENCES DimTime(date_key),
--     per_capita_gdp DECIMAL(18,2) NOT NULL,
--     rank_in_date INT NOT NULL,
--     created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
-- );

-- CREATE TABLE Result_ExportContribution(
--     analysis_id INT IDENTITY(1,1) PRIMARY KEY,
--     region_group_id TINYINT NOT NULL REFERENCES DimRegionGroup(region_group_id),
--     date_from DATE NOT NULL,
--     date_to DATE NOT NULL,
--     contribution DECIMAL(10,4) NOT NULL,
--     compare_flag CHAR(1) NOT NULL CHECK(compare_flag IN('>','=','<')),
--     created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
-- );
