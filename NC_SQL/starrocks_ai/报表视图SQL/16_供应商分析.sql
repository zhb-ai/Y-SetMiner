-- =====================================================
-- 报表16: 供应商分析
-- 业务价值: 了解供应商采购结构
-- MV依赖: MV_PRODUCT_MASTER (主供应商), IC_GENERAL_H/B (入库记录)
-- 更新频率: 每季度
-- 说明: 当前仅基于入库数据进行供应商采购量分析，
--       交货及时率/质量合格率因缺乏数据源暂不实现
-- =====================================================

-- =====================================================
-- 16.1 供应商供货商品统计
-- =====================================================
SELECT
    pm.主供应商名称 AS 供应商名称,
    COUNT(DISTINCT pm.商品主键) AS 供应商品数,
    SUM(CASE WHEN pm.是否封存 = 'N' THEN 1 ELSE 0 END) AS 有效商品数,
    ROUND(AVG(pm.结存单价), 2) AS 平均成本单价
FROM MV_PRODUCT_MASTER pm
WHERE pm.主供应商名称 IS NOT NULL
GROUP BY pm.主供应商名称
ORDER BY 供应商品数 DESC;


-- =====================================================
-- 16.2 供应商入库金额排名 (本年，通过入库单+成本价估算)
-- =====================================================
WITH 入库明细 AS (
    SELECT
        b.cinvbasid AS 商品主键,
        SUM(b.ninnum) AS 入库数量
    FROM IC_GENERAL_H h
    INNER JOIN IC_GENERAL_B b
        ON h.cgeneralhid = b.cgeneralhid
        AND b.dr = 0
    WHERE h.pk_corp = '1006'
        AND h.dr = 0
        AND h.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
        AND h.fbillflag >= 3
        AND b.ninnum > 0
        AND h.dbilldate >= CONCAT(YEAR(CURRENT_DATE()), '-01-01')
    GROUP BY b.cinvbasid
)
SELECT
    pm.主供应商名称 AS 供应商名称,
    COUNT(DISTINCT pm.商品主键) AS 入库商品数,
    SUM(rk.入库数量) AS 入库总数量,
    ROUND(SUM(rk.入库数量 * COALESCE(pm.结存单价, 0)), 2) AS 估算入库金额
FROM 入库明细 rk
INNER JOIN MV_PRODUCT_MASTER pm
    ON rk.商品主键 = pm.商品主键
WHERE pm.主供应商名称 IS NOT NULL
GROUP BY pm.主供应商名称
ORDER BY 估算入库金额 DESC;


-- =====================================================
-- 16.3 供应商品类分布
-- =====================================================
SELECT
    pm.主供应商名称 AS 供应商名称,
    pm.大类,
    pm.品牌,
    COUNT(DISTINCT pm.商品主键) AS 商品数,
    ROUND(AVG(pm.结存单价), 2) AS 平均成本单价,
    ROUND(AVG(pm.参考售价), 2) AS 平均参考售价
FROM MV_PRODUCT_MASTER pm
WHERE pm.主供应商名称 IS NOT NULL
    AND pm.是否封存 = 'N'
GROUP BY pm.主供应商名称, pm.大类, pm.品牌
ORDER BY pm.主供应商名称, 商品数 DESC;
