-- CREATE DATABASE TGP
-- COLLATE Chinese_PRC_CI_AS; 

use TGP
GO
-- 1. 区域表
CREATE TABLE region (
    region_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    level SMALLINT NOT NULL, -- 1=大区,2=省级,3=地级市,4=区县
    parent_region_id INT NULL,
    area_km2 DECIMAL(12,2) NULL,
    population BIGINT NULL,
    population_density DECIMAL(10,2) NULL,
    FOREIGN KEY (parent_region_id) REFERENCES region(region_id)
);
GO
-- 2. 时间维度表
CREATE TABLE time_dimension (
    time_id INT IDENTITY(1,1) PRIMARY KEY,
    year SMALLINT NOT NULL,
    quarter SMALLINT NULL,
    month SMALLINT NULL,
    date_label VARCHAR(20) NOT NULL
);
GO
-- 3. GDP 指标表
CREATE TABLE gdp_fact (
    gdp_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    region_id INT NOT NULL,
    time_id INT NOT NULL,
    gdp_value DECIMAL(20,2) NOT NULL,
    gdp_prev_yoy DECIMAL(10,4) NULL,
    gdp_prev_qoq DECIMAL(10,4) NULL,
    FOREIGN KEY (region_id) REFERENCES region(region_id),
    FOREIGN KEY (time_id) REFERENCES time_dimension(time_id)
);
GO
-- 4. 人均 GDP 表
CREATE TABLE per_capita_gdp (
    per_gdp_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    region_id INT NOT NULL,
    time_id INT NOT NULL,
    per_capita_gdp DECIMAL(20,2) NOT NULL,
    ranking INT NULL,
    FOREIGN KEY (region_id) REFERENCES region(region_id),
    FOREIGN KEY (time_id) REFERENCES time_dimension(time_id)
);
GO
-- 5. 对外贸易汇总表
CREATE TABLE trade_fact (
    trade_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    region_id INT NOT NULL,
    time_id INT NOT NULL,
    total_export DECIMAL(20,2) NULL,
    total_import DECIMAL(20,2) NULL,
    trade_with_us_export DECIMAL(20,2) NULL,
    trade_with_us_import DECIMAL(20,2) NULL,
    FOREIGN KEY (region_id) REFERENCES region(region_id),
    FOREIGN KEY (time_id) REFERENCES time_dimension(time_id)
);
GO
-- 6. HS 分类表
CREATE TABLE hs_category (
    hs_id INT IDENTITY(1,1) PRIMARY KEY,
    hs_code VARCHAR(10) NOT NULL,
    hs_name VARCHAR(200) NOT NULL,
    parent_hs_id INT NULL,
    FOREIGN KEY (parent_hs_id) REFERENCES hs_category(hs_id)
);
GO
-- 7. 对美进出口明细表
CREATE TABLE trade_us_detail (
    detail_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    region_id INT NOT NULL,
    time_id INT NOT NULL,
    hs_id INT NOT NULL,
    export_amount DECIMAL(20,2) NULL,
    import_amount DECIMAL(20,2) NULL,
    yoy_growth DECIMAL(10,4) NULL,
    mom_growth DECIMAL(10,4) NULL,
    FOREIGN KEY (region_id) REFERENCES region(region_id),
    FOREIGN KEY (time_id) REFERENCES time_dimension(time_id),
    FOREIGN KEY (hs_id) REFERENCES hs_category(hs_id)
);
GO
-- 8. 对外贸易流向表
CREATE TABLE trade_country (
    tc_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    region_id INT NOT NULL,
    country_code VARCHAR(10) NOT NULL,
    time_id INT NOT NULL,
    export_amount DECIMAL(20,2) NULL,
    import_amount DECIMAL(20,2) NULL,
    yoy_growth DECIMAL(10,4) NULL,
    mom_growth DECIMAL(10,4) NULL,
    FOREIGN KEY (region_id) REFERENCES region(region_id),
    FOREIGN KEY (time_id) REFERENCES time_dimension(time_id)
);
GO

