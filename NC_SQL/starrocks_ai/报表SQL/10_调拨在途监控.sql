-- =====================================================
-- 报表10: 调拨在途监控
-- 业务价值: 优化仓间调配，减少在途时间
-- MV依赖: 无（直接查询基表）
-- 更新频率: 每日
-- 超期标准: 南京>4天、西安>5天、成都>10天、沈阳>11天
-- =====================================================

-- =====================================================
-- 10.1 在途调拨清单
-- =====================================================
SELECT
    zb.vfirstcode AS 调拨单号,
    zb.dbilldate AS 单据日期,
    zb.dauditdate AS 审批日期,
    cc.storname AS 调出仓,
    rc.storname AS 调入仓,
    CONCAT(cc.storname, ' → ', rc.storname) AS 调拨路线,
    ch.invcode AS 商品编码,
    ch.invname AS 商品名称,
    ch.invpinpai AS 品牌,
    db.nnum AS 调拨数量,
    db.noutsumnum AS 已调出数量,
    DATEDIFF(CURRENT_DATE(), CAST(zb.dauditdate AS DATE)) AS 在途天数,
    CASE
        WHEN cc.storname LIKE '%南京%' OR rc.storname LIKE '%南京%' THEN 4
        WHEN cc.storname LIKE '%西安%' OR rc.storname LIKE '%西安%' THEN 5
        WHEN cc.storname LIKE '%成都%' OR rc.storname LIKE '%成都%' THEN 10
        WHEN cc.storname LIKE '%沈阳%' OR rc.storname LIKE '%沈阳%' THEN 11
        ELSE 7
    END AS 超期标准天数,
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), CAST(zb.dauditdate AS DATE)) >
            CASE
                WHEN cc.storname LIKE '%南京%' OR rc.storname LIKE '%南京%' THEN 4
                WHEN cc.storname LIKE '%西安%' OR rc.storname LIKE '%西安%' THEN 5
                WHEN cc.storname LIKE '%成都%' OR rc.storname LIKE '%成都%' THEN 10
                WHEN cc.storname LIKE '%沈阳%' OR rc.storname LIKE '%沈阳%' THEN 11
                ELSE 7
            END
        THEN '超期'
        ELSE '正常'
    END AS 在途状态
FROM TO_BILL zb
INNER JOIN TO_BILL_B db
    ON zb.cbillid = db.cbillid
    AND db.dr = 0
INNER JOIN BD_STORDOC rc
    ON db.cinwhid = rc.pk_stordoc
    AND rc.dr = 0
INNER JOIN BD_STORDOC cc
    ON db.coutwhid = cc.pk_stordoc
    AND cc.dr = 0
INNER JOIN BD_INVBASDOC ch
    ON db.cinvbasid = ch.pk_invbasdoc
    AND ch.dr = 0
WHERE zb.pk_corp = '1006'
    AND zb.dr = 0
    AND zb.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND zb.fstatusflag = 5
ORDER BY 在途天数 DESC;


-- =====================================================
-- 10.2 超期在途预警
-- =====================================================
SELECT * FROM (
    SELECT
        zb.vfirstcode AS 调拨单号,
        CONCAT(cc.storname, ' → ', rc.storname) AS 调拨路线,
        ch.invname AS 商品名称,
        db.nnum AS 调拨数量,
        zb.dauditdate AS 审批日期,
        DATEDIFF(CURRENT_DATE(), CAST(zb.dauditdate AS DATE)) AS 在途天数,
        CASE
            WHEN cc.storname LIKE '%南京%' OR rc.storname LIKE '%南京%' THEN 4
            WHEN cc.storname LIKE '%西安%' OR rc.storname LIKE '%西安%' THEN 5
            WHEN cc.storname LIKE '%成都%' OR rc.storname LIKE '%成都%' THEN 10
            WHEN cc.storname LIKE '%沈阳%' OR rc.storname LIKE '%沈阳%' THEN 11
            ELSE 7
        END AS 标准天数
    FROM TO_BILL zb
    INNER JOIN TO_BILL_B db ON zb.cbillid = db.cbillid AND db.dr = 0
    INNER JOIN BD_STORDOC rc ON db.cinwhid = rc.pk_stordoc AND rc.dr = 0
    INNER JOIN BD_STORDOC cc ON db.coutwhid = cc.pk_stordoc AND cc.dr = 0
    INNER JOIN BD_INVBASDOC ch ON db.cinvbasid = ch.pk_invbasdoc AND ch.dr = 0
    WHERE zb.pk_corp = '1006'
        AND zb.dr = 0
        AND zb.fstatusflag = 5
) t
WHERE 在途天数 > 标准天数
ORDER BY (在途天数 - 标准天数) DESC;


-- =====================================================
-- 10.3 调拨路线统计
-- =====================================================
SELECT
    CONCAT(cc.storname, ' → ', rc.storname) AS 调拨路线,
    COUNT(DISTINCT zb.cbillid) AS 调拨单数,
    SUM(db.nnum) AS 总调拨数量,
    ROUND(AVG(DATEDIFF(CURRENT_DATE(), CAST(zb.dauditdate AS DATE))), 1) AS 平均在途天数,
    MAX(DATEDIFF(CURRENT_DATE(), CAST(zb.dauditdate AS DATE))) AS 最长在途天数
FROM TO_BILL zb
INNER JOIN TO_BILL_B db ON zb.cbillid = db.cbillid AND db.dr = 0
INNER JOIN BD_STORDOC rc ON db.cinwhid = rc.pk_stordoc AND rc.dr = 0
INNER JOIN BD_STORDOC cc ON db.coutwhid = cc.pk_stordoc AND cc.dr = 0
WHERE zb.pk_corp = '1006'
    AND zb.dr = 0
    AND zb.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND zb.fstatusflag = 5
GROUP BY CONCAT(cc.storname, ' → ', rc.storname)
ORDER BY 总调拨数量 DESC;
