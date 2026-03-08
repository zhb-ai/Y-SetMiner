-- =====================================================
-- 报表17: 电商业务监控
-- 业务价值: 优化线上运营，提升电商业绩
-- MV依赖: 无（直接查询基表）
-- 更新频率: 每日
-- ⚠ 待确认: 需与业务方确认电商平台的识别方式
-- 当前假设通过 BD_BUSITYPE.businame 中包含平台关键字识别
-- 如识别方式不同，请修改 WHERE 条件中的平台筛选逻辑
-- =====================================================

-- =====================================================
-- 17.1 电商销售汇总 (按平台，本月)
-- =====================================================
SELECT
    btp.businame AS 业务类型,
    DATE_FORMAT(ii.dbilldate, '%Y-%m') AS 年月,
    COUNT(DISTINCT ii.csaleid) AS 订单数,
    SUM(ib.nnumber) AS 销售数量,
    ROUND(SUM(ib.nsummny), 2) AS 销售金额
FROM SO_SALEINVOICE ii
INNER JOIN SO_SALEINVOICE_B ib
    ON ii.csaleid = ib.csaleid
    AND ib.dr = 0
LEFT JOIN BD_BUSITYPE btp
    ON ii.biztype = btp.pk_busitype
    AND btp.dr = 0
INNER JOIN BD_INVBASDOC inv
    ON ib.cinvbasdocid = inv.pk_invbasdoc
    AND inv.dr = 0
WHERE ii.pk_corp = '1006'
    AND ii.dr = 0
    AND ii.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND btp.businame LIKE '%电商%'
    AND ii.dbilldate >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
    AND SUBSTR(inv.invcode, 1, 2) != '98'
GROUP BY btp.businame, DATE_FORMAT(ii.dbilldate, '%Y-%m')
ORDER BY 销售金额 DESC;


-- =====================================================
-- 17.2 电商商品销售排名 (本月)
-- =====================================================
SELECT
    inv.invcode AS 商品编码,
    inv.invname AS 商品名称,
    inv.invpinpai AS 品牌,
    SUM(ib.nnumber) AS 销售数量,
    ROUND(SUM(ib.nsummny), 2) AS 销售金额,
    ROW_NUMBER() OVER (ORDER BY SUM(ib.nsummny) DESC) AS 排名
FROM SO_SALEINVOICE ii
INNER JOIN SO_SALEINVOICE_B ib
    ON ii.csaleid = ib.csaleid
    AND ib.dr = 0
LEFT JOIN BD_BUSITYPE btp
    ON ii.biztype = btp.pk_busitype
    AND btp.dr = 0
INNER JOIN BD_INVBASDOC inv
    ON ib.cinvbasdocid = inv.pk_invbasdoc
    AND inv.dr = 0
WHERE ii.pk_corp = '1006'
    AND ii.dr = 0
    AND ii.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND btp.businame LIKE '%电商%'
    AND ii.dbilldate >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
    AND SUBSTR(inv.invcode, 1, 2) != '98'
GROUP BY inv.invcode, inv.invname, inv.invpinpai
ORDER BY 销售金额 DESC
LIMIT 50;


-- =====================================================
-- 17.3 电商月度趋势 (近12个月)
-- =====================================================
SELECT
    DATE_FORMAT(ii.dbilldate, '%Y-%m') AS 年月,
    COUNT(DISTINCT ii.csaleid) AS 订单数,
    SUM(ib.nnumber) AS 销售数量,
    ROUND(SUM(ib.nsummny), 2) AS 销售金额
FROM SO_SALEINVOICE ii
INNER JOIN SO_SALEINVOICE_B ib
    ON ii.csaleid = ib.csaleid
    AND ib.dr = 0
LEFT JOIN BD_BUSITYPE btp
    ON ii.biztype = btp.pk_busitype
    AND btp.dr = 0
WHERE ii.pk_corp = '1006'
    AND ii.dr = 0
    AND ii.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND btp.businame LIKE '%电商%'
    AND ii.dbilldate >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m-01')
GROUP BY DATE_FORMAT(ii.dbilldate, '%Y-%m')
ORDER BY 年月;
