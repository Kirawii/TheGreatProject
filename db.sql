-- TheGreatProject
-- CREATE DATABASE TGP COLLATE Chinese_PRC_CI_AS;
-- GO
USE TGP;
GO

-- 1.1查询指定时间段GDP最高的区域
SELECT TOP 1 DR.region_name, SUM(FG.gdp_value) AS total_gdp
FROM dbo.FactGDP FG
JOIN dbo.DimRegion DR ON FG.region_id = DR.region_id
WHERE FG.date_key BETWEEN '2023-01-31' AND '2023-12-31'
  AND DR.region_level = 2
GROUP BY DR.region_name
ORDER BY total_gdp DESC;

-- 1.2查询指定区域的地理特征，包括区域面积大小、人口数量、人口密度，等等
SELECT DR.region_name, 
       FD.area_km2, 
       FD.population, 
       CAST(FD.population * 1.0 / NULLIF(FD.area_km2, 0) AS DECIMAL(18,2)) AS population_density
FROM dbo.FactDemographics FD
JOIN dbo.DimRegion DR ON FD.region_id = DR.region_id
WHERE DR.region_name = N'重庆市'
  AND FD.date_key = '2023-12-31';


-- 1.3查询一个区域指定年份的生产总值同比增长率
WITH gdp_cte AS (
    SELECT
        r.region_name,
        t.year,
        SUM(g.gdp_value) AS total_gdp
    FROM dbo.FactGDP g
    JOIN dbo.DimRegion r ON g.region_id = r.region_id
    JOIN dbo.DimTime t ON g.date_key = t.date_key
    WHERE r.region_name = N'重庆市'
      AND t.year IN (2009, 2010)
    GROUP BY r.region_name, t.year
)
SELECT
    MAX(CASE WHEN year = 2009 THEN total_gdp END) AS gdp_2009,
    MAX(CASE WHEN year = 2010 THEN total_gdp END) AS gdp_2010,
    (MAX(CASE WHEN year = 2010 THEN total_gdp END) - MAX(CASE WHEN year = 2009 THEN total_gdp END)) * 100.0 /
    MAX(CASE WHEN year = 2009 THEN total_gdp END) AS yoy_growth_rate
FROM gdp_cte;

-- 1.4查询在指定时间段的某个区域的生产总值环比增长率。
WITH monthly_gdp AS (
    SELECT
        t.year_month,
        t.date_key,
        SUM(f.gdp_value) AS total_gdp,
        ROW_NUMBER() OVER (ORDER BY t.date_key) AS rn
    FROM dbo.FactGDP f
    JOIN dbo.DimTime t ON f.date_key = t.date_key
    JOIN dbo.DimRegion r ON f.region_id = r.region_id
    WHERE r.region_name = N'重庆市'
    GROUP BY t.date_key, t.year_month
    HAVING t.date_key BETWEEN '2022-01-31' AND '2023-12-31'
),
joined AS (
    SELECT
        curr.year_month AS curr_month,
        prev.total_gdp AS prev_gdp,
        curr.total_gdp AS curr_gdp,
        (curr.total_gdp - prev.total_gdp) * 100.0 / NULLIF(prev.total_gdp, 0) AS mom_growth
    FROM monthly_gdp curr
    JOIN monthly_gdp prev ON curr.rn = prev.rn + 1
)
SELECT * FROM joined;

-- 1.5查询指定时间段各区域的人均GDP值和排名，并且将结果存储在数据库中。
WITH per_capita AS (
    SELECT
        f.region_id,
        f.date_key,
        SUM(f.gdp_value) / NULLIF(MAX(d.population), 0) AS per_capita_gdp
    FROM dbo.FactGDP f
    JOIN dbo.FactDemographics d ON f.region_id = d.region_id AND f.date_key = d.date_key
    WHERE f.date_key = '2020-12-31'
    GROUP BY f.region_id, f.date_key
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY per_capita_gdp DESC) AS rank_in_date
    FROM per_capita
)
INSERT INTO dbo.Result_PerCapitaGDP_Ranking(region_id, date_key, per_capita_gdp, rank_in_date)
SELECT
    region_id,
    date_key,
    per_capita_gdp,
    rank_in_date
FROM ranked;


-- 1.6 分析比较指定时间段我国东部、西部、中部、东北部地区出口对该区域GDP的贡献率，以及判断贡献率是高于全国平均值，还是等于或低于平均值。将结果存储在数据库中。
DECLARE @from_date DATE = '2010-01-01';
DECLARE @to_date DATE = '2020-12-31';

-- 第一步：全国 GDP 与 出口总额
WITH NationalTotal AS (
    SELECT
        SUM(g.gdp_value) AS total_gdp,
        SUM(t.exports_value) AS total_exports
    FROM dbo.FactGDP g
    JOIN dbo.FactTrade t ON g.region_id = t.region_id AND g.date_key = t.date_key
    WHERE t.date_key BETWEEN @from_date AND @to_date
),
AvgContribution AS (
    SELECT
        CAST(total_exports AS FLOAT) / NULLIF(total_gdp, 0) AS avg_contribution
    FROM NationalTotal
),

-- 第二步：每个大区的 GDP 与 出口总额（通过省份汇总）
RegionGroupTotal AS (
    SELECT
        brg.region_group_id,
        SUM(g.gdp_value) AS total_gdp,
        SUM(t.exports_value) AS total_exports
    FROM dbo.DimRegion r
    JOIN dbo.Bridge_Region_Group brg ON r.region_id = brg.region_id
    JOIN dbo.FactGDP g ON g.region_id = r.region_id
    JOIN dbo.FactTrade t ON t.region_id = r.region_id AND t.date_key = g.date_key
    WHERE r.region_level = 2  -- 只聚合省级单位
      AND t.date_key BETWEEN @from_date AND @to_date
    GROUP BY brg.region_group_id
)

-- 第三步：插入分析结果
INSERT INTO dbo.Result_ExportContribution (
    region_group_id, date_from, date_to, contribution, compare_flag, created_at
)
SELECT
    r.region_group_id,
    @from_date,
    @to_date,
    CAST(r.total_exports AS FLOAT) / NULLIF(r.total_gdp, 0) AS contribution,
    CASE
        WHEN CAST(r.total_exports AS FLOAT) / NULLIF(r.total_gdp, 0) > a.avg_contribution THEN '>'
        WHEN CAST(r.total_exports AS FLOAT) / NULLIF(r.total_gdp, 0) = a.avg_contribution THEN '='
        ELSE '<'
    END AS compare_flag,
    SYSUTCDATETIME()
FROM RegionGroupTotal r
CROSS JOIN AvgContribution a;

-- 1.7 比较最近二十年中美贸易总额增长率变化趋势与我国GDP变化趋势。
-- 步骤：先按年汇总中美贸易总额与全国 GDP
-- 提取 2004–2023 每年中国对美国的进出口总额（贸易总额）；
-- 提取 2004–2023 每年全国 GDP 总额；
-- 计算这两个指标的同比增长率；
-- 并列输出用于趋势对比。
WITH YearlyUSATrade AS (
    SELECT
        t1.year,
        SUM(f.exports_value + f.imports_value) AS usa_trade_total
    FROM dbo.FactTrade f
    JOIN dbo.DimTime t1 ON f.date_key = t1.date_key
    WHERE f.partner_country_id = 1
    GROUP BY t1.year
),
YearlyGDP AS (
    SELECT
        t2.year,
        SUM(g.gdp_value) AS china_gdp_total
    FROM dbo.FactGDP g
    JOIN dbo.DimTime t2 ON g.date_key = t2.date_key
    WHERE g.region_id = 1
      AND t2.year BETWEEN 2004 AND 2023
    GROUP BY t2.year
),
Combined AS (
    SELECT
        t.year,
        t.usa_trade_total,
        g.china_gdp_total,
        LAG(t.usa_trade_total) OVER (ORDER BY t.year) AS prev_trade,
        LAG(g.china_gdp_total) OVER (ORDER BY t.year) AS prev_gdp
    FROM YearlyUSATrade t
    JOIN YearlyGDP g ON t.year = g.year
)
-- 输出增长率对比
SELECT
    year,
    usa_trade_total,
    china_gdp_total,
    ROUND((usa_trade_total - prev_trade) * 100.0 / NULLIF(prev_trade, 0), 2) AS usa_trade_yoy,
    ROUND((china_gdp_total - prev_gdp) * 100.0 / NULLIF(prev_gdp, 0), 2) AS gdp_yoy
FROM Combined
ORDER BY year;


-- 2
-- 2.1查询指定时间段对美出口/进口额占比最高的三类商品及金额
-- 修改年份范围
DECLARE @start_year INT = 2017, @end_year INT = 2020;

WITH CleanedData AS (
    SELECT 
        LTRIM(RTRIM(REPLACE(REPLACE(REPLACE([商品分类], CHAR(10), ''), CHAR(13), ''), '"', ''))) AS 商品分类清洗,
        年份,
        [出口_亿美元]
    FROM StagingUSTradeAnnual
    WHERE [商品分类] LIKE '第%类%'
)
SELECT TOP 3 
    商品分类清洗 AS 商品分类,
    SUM([出口_亿美元]) AS 出口总额,
    SUM([出口_亿美元]) * 1.0 / SUM(SUM([出口_亿美元])) OVER() AS 出口占比
FROM CleanedData
WHERE 年份 BETWEEN 2017 AND 2020
GROUP BY 商品分类清洗
ORDER BY 出口总额 DESC;



-- 2.2判断2018年是否存在商品出口额同比增长率为负，若无则取后20%
-- 第一步：清洗数据，筛选“第X类”形式
WITH CleanedData AS (
    SELECT 
        LTRIM(RTRIM(REPLACE(REPLACE(REPLACE([商品分类], CHAR(10), ''), CHAR(13), ''), '"', ''))) AS 商品分类,
        年份,
        [出口_亿美元]
    FROM StagingUSTradeAnnual
    WHERE [商品分类] LIKE '第%类%'
),
-- 第二步：汇总2017和2018年数据
YearlyExport AS (
    SELECT 商品分类, 年份, SUM([出口_亿美元]) AS 出口额
    FROM CleanedData
    WHERE 年份 IN (2017, 2018)
    GROUP BY 商品分类, 年份
),
-- 第三步：把数据“转横”结构用于计算增长率
ExportPivot AS (
    SELECT 
        商品分类,
        MAX(CASE WHEN 年份 = 2017 THEN 出口额 END) AS y2017,
        MAX(CASE WHEN 年份 = 2018 THEN 出口额 END) AS y2018
    FROM YearlyExport
    GROUP BY 商品分类
),
-- 第四步：计算同比增长率
Growth AS (
    SELECT 商品分类,
           y2017,
           y2018,
           CASE 
               WHEN y2017 IS NULL OR y2017 = 0 THEN NULL
               ELSE (y2018 - y2017) * 1.0 / y2017 
           END AS 增长率
    FROM ExportPivot
)
-- 第五步：判断输出
SELECT 商品分类, 增长率
FROM Growth
WHERE 增长率 < 0

UNION ALL

SELECT 商品分类, 增长率
FROM (
    SELECT 商品分类, 增长率,
           PERCENT_RANK() OVER (ORDER BY 增长率) AS rnk
    FROM Growth
) t
WHERE NOT EXISTS (SELECT 1 FROM Growth WHERE 增长率 < 0)
  AND rnk <= 0.2;


-- 2.3分析三类商品在近20年中出口占比的同比增长率趋
WITH export_total AS (
    SELECT 年份, SUM([出口_亿美元]) AS total_export
    FROM StagingUSTradeAnnual
    GROUP BY 年份
),
export_grouped AS (
    SELECT 年份,
           CASE
               WHEN 商品分类 LIKE '%纺织%' THEN '纺织制品'
               WHEN 商品分类 LIKE '%机器%' OR 商品分类 LIKE '%电气%' OR 商品分类 LIKE '%录音%' THEN '电子机械'
               WHEN 商品分类 LIKE '%车辆%' OR 商品分类 LIKE '%航空%' OR 商品分类 LIKE '%船舶%' THEN '交通运输设备'
               ELSE NULL
           END AS 商品大类,
           SUM([出口_亿美元]) AS 类别出口
    FROM StagingUSTradeAnnual
    WHERE 商品分类 LIKE '%纺织%'
       OR 商品分类 LIKE '%机器%'
       OR 商品分类 LIKE '%电气%'
       OR 商品分类 LIKE '%录音%'
       OR 商品分类 LIKE '%车辆%'
       OR 商品分类 LIKE '%航空%'
       OR 商品分类 LIKE '%船舶%'
    GROUP BY 年份,
             CASE
               WHEN 商品分类 LIKE '%纺织%' THEN '纺织制品'
               WHEN 商品分类 LIKE '%机器%' OR 商品分类 LIKE '%电气%' OR 商品分类 LIKE '%录音%' THEN '电子机械'
               WHEN 商品分类 LIKE '%车辆%' OR 商品分类 LIKE '%航空%' OR 商品分类 LIKE '%船舶%' THEN '交通运输设备'
               ELSE NULL
           END
),
export_ratio AS (
    SELECT G.年份, G.商品大类,
           G.类别出口 * 1.0 / T.total_export AS 占比
    FROM export_grouped G
    JOIN export_total T ON G.年份 = T.年份
),
growth_rate AS (
    SELECT *,
           占比 - LAG(占比) OVER (PARTITION BY 商品大类 ORDER BY 年份) AS 同比增长,
           (占比 - LAG(占比) OVER (PARTITION BY 商品大类 ORDER BY 年份)) / NULLIF(LAG(占比) OVER (PARTITION BY 商品大类 ORDER BY 年份), 0) AS 同比增长率
    FROM export_ratio
)
SELECT * FROM growth_rate
ORDER BY 商品大类, 年份;



-- (1)  查询在指定时间段指定区域的出口额在其进出口总额占比的月度环比增长率。
WITH TradeRatio AS (
    SELECT
        t.date_key,
        FORMAT(t.date_key, 'yyyy-MM') AS year_month,
        SUM(t.exports_value) AS exports,
        SUM(t.exports_value + t.imports_value) AS total_trade,
        SUM(t.exports_value) * 1.0 / NULLIF(SUM(t.exports_value + t.imports_value), 0) AS export_ratio
    FROM dbo.FactTrade t
    WHERE t.region_id = 1
      AND t.date_key BETWEEN '2010-01-01' AND '2015-12-31'
    GROUP BY t.date_key
),
RatioWithLag AS (
    SELECT
        year_month,
        export_ratio,
        LAG(export_ratio) OVER (ORDER BY year_month) AS prev_ratio
    FROM TradeRatio
)
SELECT
    year_month,
    export_ratio,
    ROUND((export_ratio - prev_ratio) * 100.0, 2) AS mom_growth_pct
FROM RatioWithLag
WHERE prev_ratio IS NOT NULL;

-- (2)  查询分析在特朗普执政的第一个任期中美贸易战爆发当年，比较中国向美国出口额月度环比变化趋势与中国对外出口总额的变化趋势。
-- 中国全国对美国出口（region_id = 1）
WITH CN_US AS (
    SELECT
        t.date_key,
        FORMAT(t.date_key, 'yyyy-MM') AS ym,
        SUM(t.exports_value) AS cn_to_us
    FROM dbo.FactTrade t
    WHERE t.region_id = 1
      AND t.partner_country_id = 1  -- 对美国
      AND t.date_key BETWEEN '2018-01-01' AND '2018-12-31'
    GROUP BY t.date_key
),

-- 中国所有省份对世界（非美国）出口
CN_ALL_WORLD AS (
    SELECT
        t.date_key,
        FORMAT(t.date_key, 'yyyy-MM') AS ym,
        SUM(t.exports_value) AS cn_province_to_world
    FROM dbo.FactTrade t
    JOIN dbo.DimRegion r ON t.region_id = r.region_id
    WHERE r.region_level = 2             -- 省级
      AND t.partner_country_id <> 1      -- 非美国
      AND t.date_key BETWEEN '2018-01-01' AND '2018-12-31'
    GROUP BY t.date_key
),

-- 拼接对比
Combined AS (
    SELECT
        us.ym,
        us.cn_to_us,
        world.cn_province_to_world,
        LAG(us.cn_to_us) OVER (ORDER BY us.ym) AS prev_us,
        LAG(world.cn_province_to_world) OVER (ORDER BY world.ym) AS prev_world
    FROM CN_US us
    JOIN CN_ALL_WORLD world ON us.ym = world.ym
)

-- 输出结果
SELECT
    ym,
    ROUND((cn_to_us - prev_us) * 100.0 / NULLIF(prev_us, 0), 2) AS us_export_mom_pct,
    ROUND((cn_province_to_world - prev_world) * 100.0 / NULLIF(prev_world, 0), 2) AS world_export_mom_pct
FROM Combined
WHERE prev_us IS NOT NULL AND prev_world IS NOT NULL
ORDER BY ym;



-- (3) 在特朗普执政第一个任期中，我国是否存在省份或直辖市出口总额年增长率持续下降？若有，查询分析该地区在这个时期的GDP年增长变化，否则提示“在这四年中，没有任何省份或直辖市出口总额年增长率都持续下降”。
-- 获取每省每年出口总额
-- 1. 获取各省每年的出口总额（2016-2020，用于计算增长率）
WITH AnnualExport AS (
    SELECT
        r.region_id,
        t.year,
        SUM(f.exports_value) AS total_exports
    FROM dbo.FactTrade f
    JOIN dbo.DimTime t ON f.date_key = t.date_key
    JOIN dbo.DimRegion r ON f.region_id = r.region_id
    WHERE r.region_level = 2  -- 省/直辖市级
      AND t.year BETWEEN 2016 AND 2020
    GROUP BY r.region_id, t.year
),

-- 2. 计算每个省份每年的出口同比增长率
ExportGrowthRate AS (
    SELECT
        region_id,
        year,
        total_exports,
        LAG(total_exports) OVER (PARTITION BY region_id ORDER BY year) AS prev_exports,
        CASE
            WHEN LAG(total_exports) OVER (PARTITION BY region_id ORDER BY year) IS NULL THEN NULL
            WHEN LAG(total_exports) OVER (PARTITION BY region_id ORDER BY year) = 0 THEN NULL
            ELSE 
                (total_exports - LAG(total_exports) OVER (PARTITION BY region_id ORDER BY year)) * 1.0 /
                LAG(total_exports) OVER (PARTITION BY region_id ORDER BY year)
        END AS growth_rate
    FROM AnnualExport
),

-- 3. 标记2017–2020年中增长率为负的年份数量
DeclineCount AS (
    SELECT
        region_id,
        SUM(CASE WHEN year BETWEEN 2017 AND 2020 AND growth_rate < 0 THEN 1 ELSE 0 END) AS decline_years
    FROM ExportGrowthRate
    GROUP BY region_id
),

-- 4. 找到增长率连续为负的省份（四年均为负）
DeclineRegion AS (
    SELECT region_id
    FROM DeclineCount
    WHERE decline_years = 4
)

-- 5. 查询这些地区的GDP变化（2017–2020）
SELECT
    t.year,
    r.region_name,
    SUM(g.gdp_value) AS total_gdp
FROM dbo.FactGDP g
JOIN dbo.DimTime t ON g.date_key = t.date_key
JOIN dbo.DimRegion r ON g.region_id = r.region_id
WHERE r.region_id IN (SELECT region_id FROM DeclineRegion)
  AND t.year BETWEEN 2017 AND 2020
GROUP BY t.year, r.region_name
ORDER BY r.region_name, t.year;




-- (4)  查询分析在特朗普第一个任期中美贸易冲突发生前，与我国贸易总额变化趋势与美国最相似的三个国家，分析比较贸易战爆发后，他们与我国贸易额和美国与我国贸易额的变化趋势。
-- 步骤1：2015~2017 各国年度贸易额
WITH CNPartnerTrade AS (
    SELECT
        f.partner_country_id,
        t.year,
        SUM(f.exports_value + f.imports_value) AS trade_amount
    FROM dbo.FactTrade f
    JOIN dbo.DimTime t ON f.date_key = t.date_key
    WHERE t.year BETWEEN 2015 AND 2017 AND f.region_id = 1
    GROUP BY f.partner_country_id, t.year
),
CountryAvg AS (
    SELECT
        partner_country_id,
        AVG(trade_amount) AS avg_trade
    FROM CNPartnerTrade
    GROUP BY partner_country_id
),
USAvg AS (
    SELECT AVG(trade_amount) AS avg_us
    FROM CNPartnerTrade
    WHERE partner_country_id = 1
),
Top3Similar AS (
    SELECT TOP 3 c.partner_country_id
    FROM CountryAvg c
    CROSS JOIN USAvg u
     WHERE c.partner_country_id != 1 
    ORDER BY ABS(c.avg_trade - u.avg_us) ASC
)

-- 步骤2：分析这些国家和美国在2018~2020的年度贸易额变化
SELECT
    t.year,
    d.country_name,
    SUM(f.exports_value + f.imports_value) AS total_trade
FROM dbo.FactTrade f
JOIN dbo.DimTime t ON f.date_key = t.date_key
JOIN dbo.DimCountry d ON f.partner_country_id = d.country_id
WHERE t.year BETWEEN 2018 AND 2020
  AND f.partner_country_id IN (
      SELECT partner_country_id FROM Top3Similar
    --   UNION SELECT 1 -- 加上美国
  )
  AND f.region_id = 1
GROUP BY t.year, d.country_name
ORDER BY d.country_name, t.year;


-- (5)  分析近十年来美国是否是中国最大的贸易顺差来源国。
WITH TenYearBalance AS (
    SELECT
        f.partner_country_id,
        SUM(f.exports_value - f.imports_value) AS trade_surplus
    FROM dbo.FactTrade f
    JOIN dbo.DimTime t ON f.date_key = t.date_key
    WHERE t.year BETWEEN 2014 AND 2023
      AND f.region_id = 1
    GROUP BY f.partner_country_id
)
SELECT TOP 1
    d.country_name,
    tb.trade_surplus
FROM TenYearBalance tb
JOIN dbo.DimCountry d ON tb.partner_country_id = d.country_id
ORDER BY tb.trade_surplus DESC;
