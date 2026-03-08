-- =====================================================
-- 报表19: 退货分析
-- 业务价值: 减少退货损失，改善产品质量和客户满意度
-- MV依赖: MV_SALES_DETAIL
-- 更新频率: 每月
-- 说明: 退货通过 MV_SALES_DETAIL 中 销售数量(noutnum) < 0 识别
--       NC结算明细中退货记录的数量为负值
-- =====================================================

-- =====================================================
-- 19.1 退货月度汇总
-- =====================================================
SELECT
    年月,
    COUNT(DISTINCT CASE WHEN 销售数量 < 0 THEN 销售结算主键 END) AS 退货单数,
    ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售数量 ELSE 0 END)) AS 退货数量,
    ROUND(ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END)), 2) AS 退货金额,
    ROUND(ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售成本 ELSE 0 END)), 2) AS 退货成本,
    COUNT(DISTINCT CASE WHEN 销售数量 > 0 THEN 销售结算主键 END) AS 正常单数,
    ROUND(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 2) AS 正常销售流水,
    ROUND(
        ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END))
        / NULLIF(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 0) * 100, 2
    ) AS 退货率
FROM MV_SALES_DETAIL
WHERE 年月 >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m')
    AND 是否赠品 = 'N'
GROUP BY 年月
ORDER BY 年月 DESC;


-- =====================================================
-- 19.2 退货客户排名 (本年)
-- =====================================================
SELECT
    客户编码,
    客户名称,
    部门名称,
    业务员姓名,
    COUNT(DISTINCT CASE WHEN 销售数量 < 0 THEN 销售结算主键 END) AS 退货单数,
    ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售数量 ELSE 0 END)) AS 退货数量,
    ROUND(ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END)), 2) AS 退货金额,
    ROUND(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 2) AS 正常销售流水,
    ROUND(
        ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END))
        / NULLIF(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 0) * 100, 2
    ) AS 退货率
FROM MV_SALES_DETAIL
WHERE 年度 = YEAR(CURRENT_DATE())
    AND 是否赠品 = 'N'
GROUP BY 客户编码, 客户名称, 部门名称, 业务员姓名
HAVING SUM(CASE WHEN 销售数量 < 0 THEN 1 ELSE 0 END) > 0
ORDER BY 退货金额 DESC;


-- =====================================================
-- 19.3 退货商品排名 (本年)
-- =====================================================
SELECT
    商品编码,
    商品名称,
    品牌,
    大类,
    ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售数量 ELSE 0 END)) AS 退货数量,
    ROUND(ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END)), 2) AS 退货金额,
    SUM(CASE WHEN 销售数量 > 0 THEN 销售数量 ELSE 0 END) AS 正常销售数量,
    ROUND(
        ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售数量 ELSE 0 END))
        / NULLIF(SUM(CASE WHEN 销售数量 > 0 THEN 销售数量 ELSE 0 END), 0) * 100, 2
    ) AS 退货率,
    ROW_NUMBER() OVER (ORDER BY ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END)) DESC) AS 排名
FROM MV_SALES_DETAIL
WHERE 年度 = YEAR(CURRENT_DATE())
    AND 是否赠品 = 'N'
GROUP BY 商品编码, 商品名称, 品牌, 大类
HAVING SUM(CASE WHEN 销售数量 < 0 THEN 1 ELSE 0 END) > 0
ORDER BY 退货金额 DESC
LIMIT 50;


-- =====================================================
-- 19.4 退货品类分析
-- =====================================================
SELECT
    品牌,
    大类,
    ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售数量 ELSE 0 END)) AS 退货数量,
    ROUND(ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END)), 2) AS 退货金额,
    ROUND(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 2) AS 正常销售流水,
    ROUND(
        ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END))
        / NULLIF(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 0) * 100, 2
    ) AS 退货率
FROM MV_SALES_DETAIL
WHERE 年度 = YEAR(CURRENT_DATE())
    AND 是否赠品 = 'N'
GROUP BY 品牌, 大类
ORDER BY 退货金额 DESC;


-- =====================================================
-- 19.5 退货部门分析
-- =====================================================
SELECT
    大部门名称,
    部门名称,
    COUNT(DISTINCT CASE WHEN 销售数量 < 0 THEN 客户主键 END) AS 退货客户数,
    ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售数量 ELSE 0 END)) AS 退货数量,
    ROUND(ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END)), 2) AS 退货金额,
    ROUND(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 2) AS 正常销售流水,
    ROUND(
        ABS(SUM(CASE WHEN 销售数量 < 0 THEN 销售流水 ELSE 0 END))
        / NULLIF(SUM(CASE WHEN 销售数量 > 0 THEN 销售流水 ELSE 0 END), 0) * 100, 2
    ) AS 退货率
FROM MV_SALES_DETAIL
WHERE 年度 = YEAR(CURRENT_DATE())
    AND 是否赠品 = 'N'
GROUP BY 大部门名称, 部门名称
ORDER BY 退货金额 DESC;
