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

-- -- Part2
-- USE TGP;
-- GO

-- -- 1.1 省级年度数据 Staging
-- IF OBJECT_ID('dbo.StagingProvince', 'U') IS NOT NULL
--     DROP TABLE dbo.StagingProvince;
-- GO
-- CREATE TABLE dbo.StagingProvince(
--     年度标识        INT              NULL,
--     省份编码        NVARCHAR(50)     NULL,
--     省份名称        NVARCHAR(100)    NULL,
--     地区生产总值     DECIMAL(18,2)    NULL,
--     人均地区生产总值  DECIMAL(18,2)    NULL,
--     年底人口数       BIGINT           NULL,
--     地区进出口总额    DECIMAL(18,2)    NULL,
--     地区出口总额      DECIMAL(18,2)    NULL,
--     地区进口总额      DECIMAL(18,2)    NULL,
--     外资企业年底注册数量 DECIMAL(18,2) NULL,
--     外资企业投资总额    DECIMAL(18,2) NULL,
--     外资企业注册资本    DECIMAL(18,2) NULL
-- );
-- GO

-- -- 1.2 地市级年度数据 Staging
-- IF OBJECT_ID('dbo.StagingCity', 'U') IS NOT NULL
--     DROP TABLE dbo.StagingCity;
-- GO
-- CREATE TABLE dbo.StagingCity(
--     年度标识       INT           NULL,
--     城市名称       NVARCHAR(100) NULL,
--     城市代码       NVARCHAR(50)  NULL,
--     省份名称       NVARCHAR(100) NULL,
--     生产总值       DECIMAL(18,2) NULL,
--     年末总人口       BIGINT        NULL,
--     人口密度       DECIMAL(18,2) NULL,
--     外商新签合同数   DECIMAL(18,2) NULL,
--     外商协议投资金额 DECIMAL(18,2) NULL,
--     外商实际投资额   DECIMAL(18,2) NULL
-- );
-- GO

-- -- 1.3 县级年度数据 Staging
-- IF OBJECT_ID('dbo.StagingCounty', 'U') IS NOT NULL
--     DROP TABLE dbo.StagingCounty;
-- GO
-- CREATE TABLE dbo.StagingCounty(
--     年度标识    INT           NULL,
--     AreaID     NVARCHAR(50)  NULL,  -- 如果需要可存储，但插入目标表无此列
--     县域名称    NVARCHAR(100) NULL,
--     隶属城市    NVARCHAR(100) NULL,
--     隶属省份    NVARCHAR(100) NULL,
--     土地面积    DECIMAL(18,2) NULL,
--     年末总人口   BIGINT        NULL,
--     地区生产总值  DECIMAL(18,2) NULL
-- );
-- GO

-- -- 3.1 插入 DimTime：从三个 Staging 表中收集年度标识
-- ;WITH Years AS (
--     SELECT DISTINCT 年度标识 AS yr FROM dbo.StagingProvince WHERE 年度标识 IS NOT NULL
--     UNION
--     SELECT DISTINCT 年度标识 FROM dbo.StagingCity WHERE 年度标识 IS NOT NULL
--     UNION
--     SELECT DISTINCT 年度标识 FROM dbo.StagingCounty WHERE 年度标识 IS NOT NULL
-- )
-- INSERT INTO dbo.DimTime(date_key, [year], [quarter], [month], month_start)
-- SELECT
--     CAST(CAST(yr AS VARCHAR(4)) + '-12-31' AS DATE) AS date_key,
--     yr AS [year],
--     4 AS [quarter],
--     12 AS [month],
--     0 AS month_start
-- FROM Years Y
-- WHERE NOT EXISTS (
--     SELECT 1 FROM dbo.DimTime WHERE date_key = CAST(CAST(Y.yr AS VARCHAR(4)) + '-12-31' AS DATE)
-- );

-- 4.1 确保国家 '中国'
-- IF NOT EXISTS (SELECT 1 FROM dbo.DimRegion WHERE region_name = N'中国' AND region_level = 0)
-- BEGIN
--     INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
--     VALUES (N'中国', 0, NULL);
-- END
-- -- 取中国 region_id
-- DECLARE @ChinaID INT = (SELECT region_id FROM dbo.DimRegion WHERE region_name = N'中国' AND region_level = 0);

-- -- 插入省级
-- INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
-- SELECT DISTINCT SP.省份名称, 2, @ChinaID
-- FROM dbo.StagingProvince SP
-- WHERE SP.省份名称 IS NOT NULL
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.DimRegion DR
--       WHERE DR.region_name = SP.省份名称 AND DR.region_level = 2
--   );

--   -- 插入地市级
-- INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
-- SELECT DISTINCT SC.城市名称, 3,
--     PR.region_id
-- FROM dbo.StagingCity SC
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SC.省份名称 AND PR.region_level = 2
-- WHERE SC.城市名称 IS NOT NULL
--   AND EXISTS (SELECT 1 FROM dbo.DimRegion PR2 WHERE PR2.region_name = SC.省份名称 AND PR2.region_level = 2)
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.DimRegion DR
--       WHERE DR.region_name = SC.城市名称 AND DR.region_level = 3
--   );

--   插入县级
-- INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
-- SELECT DISTINCT SCC.县域名称, 4,
--     CT.region_id
-- FROM dbo.StagingCounty SCC
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SCC.隶属省份 AND PR.region_level = 2
-- JOIN dbo.DimRegion CT
--     ON CT.region_name = SCC.隶属城市 AND CT.region_level = 3 AND CT.parent_region_id = PR.region_id
-- WHERE SCC.县域名称 IS NOT NULL
--   AND EXISTS (
--       SELECT 1 FROM dbo.DimRegion PR2
--       WHERE PR2.region_name = SCC.隶属省份 AND PR2.region_level = 2
--   )
--   AND EXISTS (
--       SELECT 1 FROM dbo.DimRegion CT2
--       WHERE CT2.region_name = SCC.隶属城市 AND CT2.region_level = 3 AND CT2.parent_region_id = PR.region_id
--   )
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.DimRegion DR
--       WHERE DR.region_name = SCC.县域名称 AND DR.region_level = 4
--   );

--   -- 4.1.1 插入省级 FactGDP
-- INSERT INTO dbo.FactGDP(region_id, date_key, gdp_value)
-- SELECT 
--     PR.region_id,
--     CAST(CAST(SP.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE) AS date_key,
--     SP.地区生产总值
-- FROM dbo.StagingProvince SP
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SP.省份名称 AND PR.region_level = 2
-- WHERE SP.省份名称 IS NOT NULL
--   AND SP.地区生产总值 IS NOT NULL
--   AND EXISTS (SELECT 1 FROM dbo.DimTime DT WHERE DT.date_key = CAST(CAST(SP.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE))
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.FactGDP FG
--       WHERE FG.region_id = PR.region_id 
--         AND FG.date_key = CAST(CAST(SP.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE)
--   );

-- -- 4.1.2 插入省级 FactDemographics
-- INSERT INTO dbo.FactDemographics(region_id, date_key, population, area_km2)
-- SELECT
--     PR.region_id,
--     CAST(CAST(SP.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE) AS date_key,
--     SP.年底人口数,
--     NULL AS area_km2   -- 省级数据 CSV 中无“面积”字段
-- FROM dbo.StagingProvince SP
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SP.省份名称 AND PR.region_level = 2
-- WHERE SP.省份名称 IS NOT NULL
--   AND SP.年底人口数 IS NOT NULL  -- 人口若为空则跳过
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.FactDemographics FD
--       WHERE FD.region_id = PR.region_id 
--         AND FD.date_key = CAST(CAST(SP.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE)
--   );

--   -- 4.2.1 插入市级 FactGDP
-- INSERT INTO dbo.FactGDP(region_id, date_key, gdp_value)
-- SELECT
--     CT.region_id,
--     CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE) AS date_key,
--     SC.生产总值
-- FROM dbo.StagingCity SC
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SC.省份名称 AND PR.region_level = 2
-- JOIN dbo.DimRegion CT
--     ON CT.region_name = SC.城市名称 AND CT.region_level = 3 AND CT.parent_region_id = PR.region_id
-- WHERE SC.省份名称 IS NOT NULL
--   AND SC.城市名称 IS NOT NULL
--   AND SC.生产总值 IS NOT NULL
--   AND EXISTS (SELECT 1 FROM dbo.DimTime DT WHERE DT.date_key = CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE))
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.FactGDP FG
--       WHERE FG.region_id = CT.region_id 
--         AND FG.date_key = CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE)
--   );

-- -- 4.2.2 插入市级 FactDemographics
-- INSERT INTO dbo.FactDemographics(region_id, date_key, population, area_km2)
-- SELECT
--     CT.region_id,
--     CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE) AS date_key,
--     SC.年末总人口,
--     NULL AS area_km2  -- 如果有市级“面积”可替换此处；当前 CSV 无此字段或缺失严重
-- FROM dbo.StagingCity SC
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SC.省份名称 AND PR.region_level = 2
-- JOIN dbo.DimRegion CT
--     ON CT.region_name = SC.城市名称 AND CT.region_level = 3 AND CT.parent_region_id = PR.region_id
-- WHERE SC.省份名称 IS NOT NULL
--   AND SC.城市名称 IS NOT NULL
--   AND SC.年末总人口 IS NOT NULL  -- 若为空则跳过
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.FactDemographics FD
--       WHERE FD.region_id = CT.region_id 
--         AND FD.date_key = CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE)
--   );

--   -- 4.3.1 插入县级 FactGDP
-- INSERT INTO dbo.FactGDP(region_id, date_key, gdp_value)
-- SELECT
--     CTY.region_id,
--     CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE) AS date_key,
--     SC.地区生产总值
-- FROM dbo.StagingCounty SC
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SC.隶属省份 AND PR.region_level = 2
-- JOIN dbo.DimRegion CT
--     ON CT.region_name = SC.隶属城市 AND CT.region_level = 3 AND CT.parent_region_id = PR.region_id
-- JOIN dbo.DimRegion CTY
--     ON CTY.region_name = SC.县域名称 AND CTY.region_level = 4 AND CTY.parent_region_id = CT.region_id
-- WHERE SC.隶属省份 IS NOT NULL
--   AND SC.隶属城市 IS NOT NULL
--   AND SC.县域名称 IS NOT NULL
--   AND SC.地区生产总值 IS NOT NULL
--   AND EXISTS (SELECT 1 FROM dbo.DimTime DT WHERE DT.date_key = CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE))
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.FactGDP FG
--       WHERE FG.region_id = CTY.region_id 
--         AND FG.date_key = CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE)
--   );

-- -- 4.3.2 插入县级 FactDemographics
-- INSERT INTO dbo.FactDemographics(region_id, date_key, population, area_km2)
-- SELECT
--     CTY.region_id,
--     CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE) AS date_key,
--     SC.年末总人口,
--     SC.土地面积
-- FROM dbo.StagingCounty SC
-- JOIN dbo.DimRegion PR
--     ON PR.region_name = SC.隶属省份 AND PR.region_level = 2
-- JOIN dbo.DimRegion CT
--     ON CT.region_name = SC.隶属城市 AND CT.region_level = 3 AND CT.parent_region_id = PR.region_id
-- JOIN dbo.DimRegion CTY
--     ON CTY.region_name = SC.县域名称 AND CTY.region_level = 4 AND CTY.parent_region_id = CT.region_id
-- WHERE SC.隶属省份 IS NOT NULL
--   AND SC.隶属城市 IS NOT NULL
--   AND SC.县域名称 IS NOT NULL
--   AND SC.年末总人口 IS NOT NULL   -- 人口若为空就跳过
--   -- 土地面积允许 NULL，如果 SC.土地面积 为空，插入时自动为 NULL
--   AND EXISTS (SELECT 1 FROM dbo.DimTime DT WHERE DT.date_key = CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE))
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.FactDemographics FD
--       WHERE FD.region_id = CTY.region_id 
--         AND FD.date_key = CAST(CAST(SC.年度标识 AS VARCHAR(4)) + '-12-31' AS DATE)
--   );

-- USE TGP;
-- GO

--   -- 省级区域数量
-- SELECT COUNT(*) AS 省级区域数 FROM DimRegion WHERE region_level = 2;

-- -- 地市级区域数量
-- SELECT COUNT(*) AS 地市级区域数 FROM DimRegion WHERE region_level = 3;

-- -- 县级区域数量
-- SELECT COUNT(*) AS 县级区域数 FROM DimRegion WHERE region_level = 4;

-- -- 某省某年 GDP 插入情况
-- SELECT 
--     PR.region_name, 
--     FG.date_key, 
--     FG.gdp_value
-- FROM DimRegion AS PR
-- LEFT JOIN FactGDP AS FG 
--     ON FG.region_id = PR.region_id
--     AND FG.date_key = '2023-12-31'  -- 指定年份年末日期
-- WHERE 
--     PR.region_level = 2 
--     AND PR.region_name = N'海南省';


-- -- 某地市人口插入情况
-- SELECT CT.region_name, FD.population, FD.area_km2
-- FROM DimRegion CT
-- LEFT JOIN FactDemographics FD ON FD.region_id = CT.region_id
--     AND FD.date_key = '2023-12-31'
-- WHERE CT.region_level = 3 AND CT.region_name = N'迪庆藏族自治州';

SELECT region_level, COUNT(*) AS cnt
FROM dbo.DimRegion
GROUP BY region_level
ORDER BY region_level;
-- 期望看到 level=0(中国) 1/2/3/4/..数值
SELECT 
    SCC.隶属省份, SCC.隶属城市, SCC.县域名称,
    PR.region_id AS 省ID, CT.region_id AS 市ID
FROM dbo.StagingCounty AS SCC
LEFT JOIN dbo.DimRegion AS PR 
  ON PR.region_name = LTRIM(RTRIM(SCC.隶属省份)) AND PR.region_level = 2
LEFT JOIN dbo.DimRegion AS CT 
  ON CT.region_name = LTRIM(RTRIM(SCC.隶属城市)) AND CT.region_level = 3 
     AND CT.parent_region_id = PR.region_id
WHERE SCC.隶属省份 IS NOT NULL 
  AND SCC.隶属城市 IS NOT NULL 
  AND SCC.县域名称 IS NOT NULL;

-- DROP INDEX UX_DimRegion_Name_Level ON dbo.DimRegion;

-- CREATE UNIQUE INDEX UX_DimRegion_Name_Level 
--   ON dbo.DimRegion(region_name, region_level, parent_region_id);

-- 4.1 确保国家 '中国'
-- IF NOT EXISTS (SELECT 1 FROM dbo.DimRegion WHERE region_name = N'中国' AND region_level = 0)
-- BEGIN
--     INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
--     VALUES (N'中国', 0, NULL);
-- END
-- -- 取中国 region_id
-- DECLARE @ChinaID INT = (SELECT region_id FROM dbo.DimRegion WHERE region_name = N'中国' AND region_level = 0);


-- -- 省级（parent_region_id = 中国ID）
-- INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
-- SELECT DISTINCT LTRIM(RTRIM(SP.省份名称)), 2, @ChinaID
-- FROM dbo.StagingProvince AS SP
-- WHERE SP.省份名称 IS NOT NULL
--   AND NOT EXISTS (
--       SELECT 1 
--       FROM dbo.DimRegion DR
--       WHERE DR.region_level = 2
--         AND DR.region_name = LTRIM(RTRIM(SP.省份名称))
--         AND DR.parent_region_id = @ChinaID
--   );

-- -- 市级（parent_region_id = 对应省ID）
-- INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
-- SELECT DISTINCT LTRIM(RTRIM(SC.城市名称)), 3, PR.region_id
-- FROM dbo.StagingCity AS SC
-- JOIN dbo.DimRegion AS PR
--   ON PR.region_name = LTRIM(RTRIM(SC.省份名称)) 
--  AND PR.region_level = 2
-- WHERE SC.城市名称 IS NOT NULL
--   AND NOT EXISTS (
--       SELECT 1 
--       FROM dbo.DimRegion DR
--       WHERE DR.region_level = 3
--         AND DR.region_name = LTRIM(RTRIM(SC.城市名称))
--         AND DR.parent_region_id = PR.region_id
--   );
-- -- 县级（parent_region_id = 对应市ID）
-- INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
-- SELECT DISTINCT LTRIM(RTRIM(SCC.县域名称)), 4, CT.region_id
-- FROM dbo.StagingCounty AS SCC
-- JOIN dbo.DimRegion AS PR
--   ON PR.region_name = LTRIM(RTRIM(SCC.隶属省份)) AND PR.region_level = 2
-- JOIN dbo.DimRegion AS CT
--   ON CT.region_name = LTRIM(RTRIM(SCC.隶属城市)) AND CT.region_level = 3 
--  AND CT.parent_region_id = PR.region_id
-- WHERE SCC.隶属省份 IS NOT NULL
--   AND SCC.隶属城市 IS NOT NULL
--   AND SCC.县域名称 IS NOT NULL
--   AND NOT EXISTS (
--       SELECT 1 
--       FROM dbo.DimRegion DR
--       WHERE DR.region_level = 4
--         AND DR.region_name = LTRIM(RTRIM(SCC.县域名称))
--         AND DR.parent_region_id = CT.region_id
--   );
-- INSERT INTO dbo.DimRegion(region_name, region_level, parent_region_id)
-- SELECT DISTINCT 
--     LTRIM(RTRIM(SCC.县域名称)), 
--     4, 
--     CT.region_id
-- FROM dbo.StagingCounty AS SCC
-- JOIN dbo.DimRegion AS PR 
--   ON PR.region_name = LTRIM(RTRIM(SCC.隶属省份)) AND PR.region_level = 2
-- JOIN dbo.DimRegion AS CT 
--   ON CT.region_name = LTRIM(RTRIM(SCC.隶属城市)) AND CT.region_level = 3 
--      AND CT.parent_region_id = PR.region_id
-- WHERE SCC.隶属省份 IS NOT NULL 
--   AND SCC.隶属城市 IS NOT NULL 
--   AND SCC.县域名称 IS NOT NULL
--   AND NOT EXISTS (
--       SELECT 1 FROM dbo.DimRegion DR 
--       WHERE DR.region_name = LTRIM(RTRIM(SCC.县域名称)) 
--         AND DR.region_level = 4 
--         AND DR.parent_region_id = CT.region_id
--   );
