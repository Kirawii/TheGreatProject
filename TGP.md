# TGP

## 分析需求

本课程设计包括两个部分：数据库设计和查询分析程序。

（一）  数据库系统支持至少以下查询分析：

查询分析中美贸易冲突背景下我国国民生产总值增长趋势。以下第（１）至（5）小题要求仅编写一条SQL命令实现查询。

(1)  查询指定时间段GDP最高的区域

(2)  查询指定区域的地理特征，包括区域面积大小、人口数量、人口密度，等等

(3)  查询一个区域指定年份的生产总值同比增长率

(4)  查询在指定时间段的某个区域的生产总值环比增长率。

(5)  查询指定时间段各区域的人均GDP值和排名，并且将结果存储在数据库中。

(6)  分析比较指定时间段我国东部、西部、中部、东北部地区出口对该区域GDP的贡献率，以及判断贡献率是高于全国平均值，还是等于或低于平均值。将结果存储在数据库中。

(7)  比较最近二十年中美贸易总额增长率变化趋势与我国GDP变化趋势。

查询分析中美贸易冲突背景下我国对外贸易流向变化

(1)  查询在指定时间段指定区域的出口额在其进出口总额占比的月度环比增长率。

(2)  查询分析在特朗普执政的第一个任期中美贸易战爆发当年，比较中国向美国出口额月度环比变化趋势与中国对外出口总额的变化趋势。

(3) 在特朗普执政第一个任期中，我国是否存在省份或直辖市出口总额年增长率持续下降？若有，查询分析该地区在这个时期的GDP年增长变化，否则提示“在这四年中，没有任何省份或直辖市出口总额年增长率都持续下降”。

(4)  查询分析在特朗普第一个任期中美贸易冲突发生前，与我国贸易总额变化趋势与美国最相似的三个国家，分析比较贸易战爆发后，他们与我国贸易额和美国与我国贸易额的变化趋势。

(5)  分析近十年来美国是否是中国最大的贸易顺差来源国。

（二） 除了完成以上描述的基本任务，每个小组还需自主确定该数据库应用系统还能支持哪些与对外贸易对我国经济和金融市场的影响等相关问题的研究，例如，中美贸易战对人民币对美元汇率的影响、对我国债市的影响和对外商对我国投资的影响，等等，尝试发现有趣的结果。

 (三) 对数据库查询分析结果进行适当的可视化，可采用其它工具。

(四) 注意：

1   区域划分有多种层次标准。第一级按东、西、中、东北等地区划分；第二级按省份、自治区和直辖市；第3级按城市；第4级按区县；等等。划分粒度越小越好。以上基本要求中如果没有明确区域粒度，至少是第二级区域。

2   时间周期划分也有多种层次结构。可按年、季、月，等等。划分粒度越小越好，但主要依赖于你们能够采集到的数据。

3   本项目设计强调尽量减少数据冗余，以减少数据库数据操纵出现异常的可能性。

4   对以上问题进行查询，编写SQL程序代码，显示结果，同时还需要在设计报告中的阐述查询的思路。

## 表格设计

### 表结构

| 表名                            | 类型 | 业务粒度       | 主键 / 组合键                               | 关键字段                                            | 能支撑的核心查询                         |
| ------------------------------- | ---- | -------------- | ------------------------------------------- | --------------------------------------------------- | ---------------------------------------- |
| **DimTime**                     | 维度 | 日期 (天)      | `date_key`                                  | `year`,`quarter`,`month`,`year_month`,`month_start` | 所有按年/季/月的同比、环比、趋势分析     |
| **DimRegion**                   | 维度 | 行政区         | `region_id`                                 | `region_name`,`region_level`,`parent_region_id`     | GDP 与贸易按省/市/区县到大区的钻取       |
| **DimCountry**                  | 维度 | 贸易伙伴国     | `country_id`                                | `country_name`                                      | 进出口对象筛选（中美比较、TOP N 伙伴等） |
| **DimRegionGroup**              | 维度 | 大区分组       | `region_group_id`                           | `group_name`                                        | 东部/中部/西部/东北聚合                  |
| **Bridge_Region_Group**         | 桥表 | 区域–大区映射  | `region_id`,`region_group_id`               | —                                                   | 各省归属大区的多对多关系                 |
| **FactGDP**                     | 事实 | 区域×日期      | `region_id`,`date_key`                      | `gdp_value`                                         | (1)–(5)、(7) 及出口贡献率分母            |
| **FactDemographics**            | 事实 | 区域×日期      | `region_id`,`date_key`                      | `population`,`area_km2`                             | 动态面积、人口、人口密度、人均 GDP       |
| **FactTrade**                   | 事实 | 区域×国家×日期 | `region_id`,`partner_country_id`,`date_key` | `exports_value`,`imports_value`                     | 全部贸易相关查询 (1)-(2)-2-(5)           |
| **Result_PerCapitaGDP_Ranking** | 结果 | 区域×日期      | `analysis_id`                               | `per_capita_gdp`,`rank_in_date`                     | (1)-(5) 结果持久化                       |
| **Result_ExportContribution**   | 结果 | 大区×区间      | `analysis_id`                               | `contribution`,`compare_flag`,`date_from`,`date_to` | (1)-(6) 出口贡献率比较                   |

### 表分析

| 查询需求                                         | 所需数据                                                     | 结构支持情况 | 说明                                                         |
| ------------------------------------------------ | ------------------------------------------------------------ | ------------ | ------------------------------------------------------------ |
| **1-(1)** 指定时间段 GDP 最高区域                | FactGDP, DimTime, DimRegion                                  | ✔            | 按 `date_key BETWEEN …` 聚合 SUM(gdp_value) GROUP BY region_id ORDER BY DESC |
| **1-(2)** 指定区域地理特征                       | FactDemographics                                             | ✔            | 任选日期快照，人口密度 = population / area_km2               |
| **1-(3)** 区域年度同比                           | FactGDP                                                      | ✔            | `LAG(SUM(gdp_value)) OVER (PARTITION BY region_id ORDER BY year)` |
| **1-(4)** 区域月度环比                           | FactGDP                                                      | ✔            | `LAG` 按月序号                                               |
| **1-(5)** 人均 GDP 与排名                        | FactGDP + FactDemographics → Result_PerCapitaGDP_Ranking     | ✔            | 当期人口取 FactDemographics，同步写入结果表                  |
| **1-(6)** 大区出口贡献率比较                     | FactTrade + FactGDP + Bridge_Region_Group + DimRegionGroup → Result_ExportContribution | ✔            | 先汇总大区出口额与 GDP，再与全国平均比                       |
| **1-(7)** 20 年中美贸易额 vs GDP                 | FactTrade (USA), FactGDP (全国)                              | ✔            | 汇总全国 region_level=0，partner=USA                         |
| **2-(1)** 区域出口额占比环比                     | FactTrade                                                    | ✔            | 先计算 `exports / (exports+imports)`，再 `LAG`               |
| **2-(2)** 特朗普任期中国对美出口环比 vs 全国出口 | FactTrade                                                    | ✔            | 两条子查询后 LEFT JOIN 时间线对比                            |
| **2-(3)** 连续 4 年出口年增率下降省份            | FactTrade, DimRegion (省级), FactGDP                         | ✔            | 用窗口函数计算 YOY，布尔累积检测；若存在再查 GDP             |
| **2-(4)** 贸易战前后相似国家比较                 | FactTrade, DimCountry                                        | ✔            | 赛前用相关系数或距离度量选 3 国，再拉同期汇总比对            |
| **2-(5)** 近十年最大贸易顺差来源国               | FactTrade                                                    | ✔            | 按 partner 求 `SUM(exports-imports)` 排序                    |

### 表代码

```mssql
CREATE DATABASE TradeGDPAnalytics;
GO
USE TradeGDPAnalytics;
GO

CREATE TABLE DimTime(
    date_key DATE PRIMARY KEY,
    [year] INT NOT NULL,
    [quarter] TINYINT NOT NULL CHECK([quarter] BETWEEN 1 AND 4),
    [month] TINYINT NOT NULL CHECK([month] BETWEEN 1 AND 12),
    year_month AS (FORMAT(date_key,'yyyy-MM')) PERSISTED,
    month_start BIT NOT NULL DEFAULT 0
);

CREATE TABLE DimRegion(
    region_id INT IDENTITY(1,1) PRIMARY KEY,
    region_name NVARCHAR(100) NOT NULL,
    region_level TINYINT NOT NULL CHECK(region_level BETWEEN 0 AND 5),
    parent_region_id INT NULL REFERENCES DimRegion(region_id)
);
CREATE UNIQUE INDEX UX_DimRegion_Name_Level ON DimRegion(region_name,region_level);

CREATE TABLE DimRegionGroup(
    region_group_id TINYINT PRIMARY KEY,
    group_name NVARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE Bridge_Region_Group(
    region_id INT NOT NULL REFERENCES DimRegion(region_id),
    region_group_id TINYINT NOT NULL REFERENCES DimRegionGroup(region_group_id),
    PRIMARY KEY(region_id,region_group_id)
);

CREATE TABLE DimCountry(
    country_id INT IDENTITY(1,1) PRIMARY KEY,
    country_name NVARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE FactGDP(
    region_id INT NOT NULL REFERENCES DimRegion(region_id),
    date_key DATE NOT NULL REFERENCES DimTime(date_key),
    gdp_value DECIMAL(18,2) NOT NULL,
    PRIMARY KEY(region_id,date_key)
);
CREATE INDEX IX_FactGDP_DateRegion ON FactGDP(date_key,region_id);

CREATE TABLE FactDemographics(
    region_id INT NOT NULL REFERENCES DimRegion(region_id),
    date_key DATE NOT NULL REFERENCES DimTime(date_key),
    population BIGINT NOT NULL,
    area_km2 DECIMAL(18,2) NULL,
    PRIMARY KEY(region_id,date_key)
);
CREATE INDEX IX_Demo_DateRegion ON FactDemographics(date_key,region_id);

CREATE TABLE FactTrade(
    region_id INT NOT NULL REFERENCES DimRegion(region_id),
    partner_country_id INT NOT NULL REFERENCES DimCountry(country_id),
    date_key DATE NOT NULL REFERENCES DimTime(date_key),
    exports_value DECIMAL(18,2) NULL,
    imports_value DECIMAL(18,2) NULL,
    PRIMARY KEY(region_id,partner_country_id,date_key)
);
CREATE INDEX IX_Trade_Date_RegionCountry ON FactTrade(date_key,region_id,partner_country_id);

CREATE TABLE Result_PerCapitaGDP_Ranking(
    analysis_id INT IDENTITY(1,1) PRIMARY KEY,
    region_id INT NOT NULL REFERENCES DimRegion(region_id),
    date_key DATE NOT NULL REFERENCES DimTime(date_key),
    per_capita_gdp DECIMAL(18,2) NOT NULL,
    rank_in_date INT NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE Result_ExportContribution(
    analysis_id INT IDENTITY(1,1) PRIMARY KEY,
    region_group_id TINYINT NOT NULL REFERENCES DimRegionGroup(region_group_id),
    date_from DATE NOT NULL,
    date_to DATE NOT NULL,
    contribution DECIMAL(10,4) NOT NULL,
    compare_flag CHAR(1) NOT NULL CHECK(compare_flag IN('>','=','<')),
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

```

## 数据收集与处理



## 查询语句