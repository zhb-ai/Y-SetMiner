-- =====================================================
-- 报表12: 客户信用管理
-- 业务价值: 控制信用风险，优化授信策略
-- MV依赖: MV_CUSTOMER_MASTER (信用额度) + ARAP_DJFB (已用额度)
-- 更新频率: 每日 (T+1)
-- =====================================================

-- =====================================================
-- 12.1 客户信用总览
-- =====================================================
WITH 已用额度 AS (
    SELECT
        fb.hbbm AS 客户主键,
        ROUND(SUM(fb.bbye), 2) AS 未核销余额
    FROM ARAP_DJFB fb
    WHERE fb.pk_corp = '1006'
        AND fb.dr = 0
        AND fb.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
        AND fb.djdl = 'ys'
        AND fb.isverifyfinished = 'N'
    GROUP BY fb.hbbm
)
SELECT
    cm.客户编码,
    cm.客户名称,
    cm.部门名称,
    cm.业务员姓名,
    cm.付款协议名称,
    cm.账期天数,
    ROUND(COALESCE(cm.信用额度, 0), 2) AS 信用额度,
    ROUND(COALESCE(cm.临时信用额度, 0), 2) AS 临时信用额度,
    ROUND(COALESCE(cm.总信用额度, 0), 2) AS 总信用额度,
    COALESCE(ar.未核销余额, 0) AS 已用额度,
    ROUND(COALESCE(cm.总信用额度, 0) - COALESCE(ar.未核销余额, 0), 2) AS 可用额度,
    CASE
        WHEN COALESCE(cm.总信用额度, 0) = 0 THEN 0
        ELSE ROUND(COALESCE(ar.未核销余额, 0) / cm.总信用额度 * 100, 2)
    END AS 额度使用率
FROM MV_CUSTOMER_MASTER cm
LEFT JOIN 已用额度 ar ON cm.客户主键 = ar.客户主键
WHERE cm.总信用额度 > 0
    AND cm.是否封存 = 'N'
ORDER BY 额度使用率 DESC;


-- =====================================================
-- 12.2 超限客户预警
-- =====================================================
WITH 已用额度 AS (
    SELECT
        fb.hbbm AS 客户主键,
        ROUND(SUM(fb.bbye), 2) AS 未核销余额
    FROM ARAP_DJFB fb
    WHERE fb.pk_corp = '1006'
        AND fb.dr = 0
        AND fb.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
        AND fb.djdl = 'ys'
        AND fb.isverifyfinished = 'N'
    GROUP BY fb.hbbm
)
SELECT
    cm.客户编码,
    cm.客户名称,
    cm.业务员姓名,
    cm.部门名称,
    ROUND(cm.总信用额度, 2) AS 总信用额度,
    ar.未核销余额 AS 已用额度,
    ROUND(cm.总信用额度 - ar.未核销余额, 2) AS 可用额度,
    ROUND(ar.未核销余额 / NULLIF(cm.总信用额度, 0) * 100, 2) AS 额度使用率,
    CASE
        WHEN ar.未核销余额 > cm.总信用额度 THEN '超限'
        WHEN ar.未核销余额 / NULLIF(cm.总信用额度, 0) > 0.8 THEN '高风险'
        ELSE '正常'
    END AS 风险等级
FROM MV_CUSTOMER_MASTER cm
INNER JOIN 已用额度 ar ON cm.客户主键 = ar.客户主键
WHERE cm.总信用额度 > 0
    AND cm.是否封存 = 'N'
    AND ar.未核销余额 / NULLIF(cm.总信用额度, 0) > 0.8
ORDER BY 额度使用率 DESC;


-- =====================================================
-- 12.3 部门信用风险汇总
-- =====================================================
WITH 已用额度 AS (
    SELECT
        fb.hbbm AS 客户主键,
        ROUND(SUM(fb.bbye), 2) AS 未核销余额
    FROM ARAP_DJFB fb
    WHERE fb.pk_corp = '1006'
        AND fb.dr = 0
        AND fb.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
        AND fb.djdl = 'ys'
        AND fb.isverifyfinished = 'N'
    GROUP BY fb.hbbm
)
SELECT
    cm.大部门名称,
    cm.部门名称,
    COUNT(DISTINCT cm.客户主键) AS 授信客户数,
    ROUND(SUM(cm.总信用额度), 2) AS 总授信额度,
    ROUND(SUM(COALESCE(ar.未核销余额, 0)), 2) AS 总已用额度,
    ROUND(SUM(COALESCE(ar.未核销余额, 0)) / NULLIF(SUM(cm.总信用额度), 0) * 100, 2) AS 总使用率,
    SUM(CASE WHEN COALESCE(ar.未核销余额, 0) > cm.总信用额度 THEN 1 ELSE 0 END) AS 超限客户数
FROM MV_CUSTOMER_MASTER cm
LEFT JOIN 已用额度 ar ON cm.客户主键 = ar.客户主键
WHERE cm.总信用额度 > 0
    AND cm.是否封存 = 'N'
GROUP BY cm.大部门名称, cm.部门名称
ORDER BY 总使用率 DESC;
