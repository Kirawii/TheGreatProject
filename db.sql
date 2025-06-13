-- -- Part1
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

-- Part2
USE TGP;
GO

-- 1.1 省级年度数据 Staging
IF OBJECT_ID('dbo.StagingProvince', 'U') IS NOT NULL
    DROP TABLE dbo.StagingProvince;
GO
CREATE TABLE dbo.StagingProvince(
    年度标识        INT              NULL,
    省份编码        NVARCHAR(50)     NULL,
    省份名称        NVARCHAR(100)    NULL,
    地区生产总值     DECIMAL(18,2)    NULL,
    人均地区生产总值  DECIMAL(18,2)    NULL,
    年底人口数       BIGINT           NULL,
    地区进出口总额    DECIMAL(18,2)    NULL,
    地区出口总额      DECIMAL(18,2)    NULL,
    地区进口总额      DECIMAL(18,2)    NULL,
    外资企业年底注册数量 DECIMAL(18,2) NULL,
    外资企业投资总额    DECIMAL(18,2) NULL,
    外资企业注册资本    DECIMAL(18,2) NULL
);
GO

-- 1.2 地市级年度数据 Staging
IF OBJECT_ID('dbo.StagingCity', 'U') IS NOT NULL
    DROP TABLE dbo.StagingCity;
GO
CREATE TABLE dbo.StagingCity(
    年度标识       INT           NULL,
    城市名称       NVARCHAR(100) NULL,
    城市代码       NVARCHAR(50)  NULL,
    省份名称       NVARCHAR(100) NULL,
    生产总值       DECIMAL(18,2) NULL,
    年末总人口       BIGINT        NULL,
    人口密度       DECIMAL(18,2) NULL,
    外商新签合同数   DECIMAL(18,2) NULL,
    外商协议投资金额 DECIMAL(18,2) NULL,
    外商实际投资额   DECIMAL(18,2) NULL
);
GO

-- 1.3 县级年度数据 Staging
IF OBJECT_ID('dbo.StagingCounty', 'U') IS NOT NULL
    DROP TABLE dbo.StagingCounty;
GO
CREATE TABLE dbo.StagingCounty(
    年度标识    INT           NULL,
    AreaID     NVARCHAR(50)  NULL,  -- 如果需要可存储，但插入目标表无此列
    县域名称    NVARCHAR(100) NULL,
    隶属城市    NVARCHAR(100) NULL,
    隶属省份    NVARCHAR(100) NULL,
    土地面积    DECIMAL(18,2) NULL,
    年末总人口   BIGINT        NULL,
    地区生产总值  DECIMAL(18,2) NULL
);
GO

-- USE TGP;
-- GO
-- BULK INSERT dbo.StagingProvince
-- FROM '/var/opt/mssql/data/province.csv'
-- WITH (
--     FIRSTROW = 2,
--     FIELDTERMINATOR = ',',
--     ROWTERMINATOR = '\n',
--     TABLOCK
-- );
-- GO
-- BULK INSERT dbo.StagingCity
-- FROM '/var/opt/mssql/data/市级数据-年度.csv'
-- WITH (
--     FIRSTROW = 2,
--     FORMAT='CSV',
--     FIELDQUOTE='"',
--     TABLOCK
-- );
-- GO
-- BULK INSERT dbo.StagingCounty
-- FROM '/var/opt/mssql/data/县级数据-年度.csv'
-- WITH (
--     FIRSTROW = 2,
--     FIELDTERMINATOR = ',',
--     ROWTERMINATOR = '\n',
--     TABLOCK
-- );
-- GO
