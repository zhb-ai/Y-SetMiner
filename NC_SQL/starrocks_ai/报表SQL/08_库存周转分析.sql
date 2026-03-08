-- =====================================================
-- 报表8: 库存周转分析
-- 业务价值: 识别呆滞库存，提高周转效率
-- MV依赖: MV_INVENTORY_SNAPSHOT (库存), MV_SALES_DETAIL (销售成本)
-- 更新频率: 每周
-- 说明: 使用当前库存快照作为平均库存近似值，
--       实际平均库存需历史快照数据（当前不可用）
-- =====================================================

-- =====================================================
-- 8.1 商品周转率排名 (近90天)
-- =====================================================
WITH 库存 AS (
    SELECT
        商品主键,
        商品编码,
        商品名称,
        品牌,
        大类,
        SUM(结存数量) AS 结存数量,
        ROUND(SUM(库存金额), 2) AS 库存金额
    FROM MV_INVENTORY_SNAPSHOT
    GROUP BY 商品主键, 商品编码, 商品名称, 品牌, 大类
),
销售 AS (
    SELECT
        商品主键,
        ROUND(SUM(销售成本), 2) AS 近90天销售成本,
        SUM(销售数量) AS 近90天销售数量
    FROM MV_SALES_DETAIL
    WHERE 制单日期 >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
        AND 是否赠品 = 'N'
    GROUP BY 商品主键
)
SELECT
    k.商品编码,
    k.商品名称,
    k.品牌,
    k.大类,
    k.结存数量,
    ROUND(k.库存金额, 2) AS 库存金额,
    COALESCE(x.近90天销售成本, 0) AS 近90天销售成本,
    COALESCE(x.近90天销售数量, 0) AS 近90天销售数量,
    CASE
        WHEN COALESCE(x.近90天销售成本, 0) = 0 THEN 9999
        ELSE ROUND(90 * k.库存金额 / x.近90天销售成本, 0)
    END AS 周转天数,
    CASE
        WHEN k.库存金额 = 0 THEN 0
        ELSE ROUND(COALESCE(x.近90天销售成本, 0) / k.库存金额, 2)
    END AS 周转率
FROM 库存 k
LEFT JOIN 销售 x ON k.商品主键 = x.商品主键
WHERE k.库存金额 > 0
ORDER BY 周转天数 DESC;


-- =====================================================
-- 8.2 呆滞库存清单 (180天无销售)
-- =====================================================
WITH 近半年有销售 AS (
    SELECT DISTINCT 商品主键
    FROM MV_SALES_DETAIL
    WHERE 制单日期 >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
)
SELECT
    inv.商品编码,
    inv.商品名称,
    inv.品牌,
    inv.大类,
    inv.仓库名称,
    inv.结存数量,
    ROUND(inv.库存金额, 2) AS 库存金额,
    '呆滞' AS 状态
FROM MV_INVENTORY_SNAPSHOT inv
LEFT JOIN 近半年有销售 s ON inv.商品主键 = s.商品主键
WHERE s.商品主键 IS NULL
    AND inv.库存金额 > 0
ORDER BY inv.库存金额 DESC;


-- =====================================================
-- 8.3 品类周转对比
-- =====================================================
WITH 库存 AS (
    SELECT 大类, 品牌, ROUND(SUM(库存金额), 2) AS 库存金额
    FROM MV_INVENTORY_SNAPSHOT
    GROUP BY 大类, 品牌
),
销售 AS (
    SELECT 大类, 品牌, ROUND(SUM(销售成本), 2) AS 近90天成本
    FROM MV_SALES_DETAIL
    WHERE 制单日期 >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
        AND 是否赠品 = 'N'
    GROUP BY 大类, 品牌
)
SELECT
    COALESCE(k.大类, x.大类) AS 大类,
    COALESCE(k.品牌, x.品牌) AS 品牌,
    COALESCE(k.库存金额, 0) AS 库存金额,
    COALESCE(x.近90天成本, 0) AS 近90天销售成本,
    CASE
        WHEN COALESCE(x.近90天成本, 0) = 0 THEN 9999
        ELSE ROUND(90 * COALESCE(k.库存金额, 0) / x.近90天成本, 0)
    END AS 周转天数
FROM 库存 k
FULL OUTER JOIN 销售 x ON k.大类 = x.大类 AND k.品牌 = x.品牌
ORDER BY 周转天数 DESC;


-- =====================================================
-- 8.4 呆滞库存汇总 (按品类)
-- =====================================================
WITH 近半年有销售 AS (
    SELECT DISTINCT 商品主键
    FROM MV_SALES_DETAIL
    WHERE 制单日期 >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
)
SELECT
    inv.品牌,
    inv.大类,
    COUNT(DISTINCT inv.商品主键) AS 呆滞商品数,
    SUM(inv.结存数量) AS 呆滞数量,
    ROUND(SUM(inv.库存金额), 2) AS 呆滞金额,
    ROUND(SUM(inv.库存金额) / NULLIF(SUM(SUM(inv.库存金额)) OVER (), 0) * 100, 2) AS 呆滞占比
FROM MV_INVENTORY_SNAPSHOT inv
LEFT JOIN 近半年有销售 s ON inv.商品主键 = s.商品主键
WHERE s.商品主键 IS NULL
    AND inv.库存金额 > 0
GROUP BY inv.品牌, inv.大类
ORDER BY 呆滞金额 DESC;
