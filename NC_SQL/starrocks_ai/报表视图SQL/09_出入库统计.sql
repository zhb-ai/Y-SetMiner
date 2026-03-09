-- =====================================================
-- 报表9: 出入库统计
-- 业务价值: 监控货物流转，平衡出入库
-- MV依赖: 无（直接查询基表）
-- 更新频率: 每日
-- =====================================================

-- =====================================================
-- 9.1 每日出入库汇总
-- =====================================================
SELECT
    h.dbilldate AS 单据日期,
    bt.billtypename AS 单据类型,
    COUNT(DISTINCT h.cgeneralhid) AS 单据数,
    SUM(b.ninnum) AS 入库数量,
    SUM(b.noutnum) AS 出库数量
FROM IC_GENERAL_H h
INNER JOIN IC_GENERAL_B b
    ON h.cgeneralhid = b.cgeneralhid
    AND b.dr = 0
INNER JOIN BD_BILLTYPE bt
    ON h.cbilltypecode = bt.pk_billtypecode
    AND bt.dr = 0
WHERE h.pk_corp = '1006'
    AND h.dr = 0
    AND h.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND h.fbillflag >= 3
    AND h.dbilldate >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY), '%Y-%m-%d')
GROUP BY h.dbilldate, bt.billtypename
ORDER BY h.dbilldate DESC, bt.billtypename;


-- =====================================================
-- 9.2 按仓库出入库统计 (本月)
-- =====================================================
SELECT
    stor.storname AS 仓库名称,
    bt.billtypename AS 单据类型,
    COUNT(DISTINCT h.cgeneralhid) AS 单据数,
    SUM(b.ninnum) AS 入库数量,
    SUM(b.noutnum) AS 出库数量
FROM IC_GENERAL_H h
INNER JOIN IC_GENERAL_B b
    ON h.cgeneralhid = b.cgeneralhid
    AND b.dr = 0
INNER JOIN BD_BILLTYPE bt
    ON h.cbilltypecode = bt.pk_billtypecode
    AND bt.dr = 0
LEFT JOIN BD_STORDOC stor
    ON h.cwarehouseid = stor.pk_stordoc
    AND stor.dr = 0
WHERE h.pk_corp = '1006'
    AND h.dr = 0
    AND h.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND h.fbillflag >= 3
    AND h.dbilldate >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
GROUP BY stor.storname, bt.billtypename
ORDER BY stor.storname, bt.billtypename;


-- =====================================================
-- 9.3 按商品出入库统计 (本月)
-- =====================================================
SELECT
    inv.invcode AS 商品编码,
    inv.invname AS 商品名称,
    inv.invpinpai AS 品牌,
    inv.width AS 大类,
    SUM(b.ninnum) AS 入库数量,
    SUM(b.noutnum) AS 出库数量,
    SUM(b.ninnum) - SUM(b.noutnum) AS 净入库数量
FROM IC_GENERAL_H h
INNER JOIN IC_GENERAL_B b
    ON h.cgeneralhid = b.cgeneralhid
    AND b.dr = 0
INNER JOIN BD_INVBASDOC inv
    ON b.cinvbasid = inv.pk_invbasdoc
    AND inv.dr = 0
WHERE h.pk_corp = '1006'
    AND h.dr = 0
    AND h.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND h.fbillflag >= 3
    AND h.dbilldate >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
    AND SUBSTR(inv.invcode, 1, 2) != '98'
GROUP BY inv.invcode, inv.invname, inv.invpinpai, inv.width
ORDER BY SUM(b.noutnum) DESC;


-- =====================================================
-- 9.4 出入库月度趋势 (近12个月)
-- =====================================================
SELECT
    DATE_FORMAT(h.dbilldate, '%Y-%m') AS 年月,
    SUM(b.ninnum) AS 入库总量,
    SUM(b.noutnum) AS 出库总量,
    COUNT(DISTINCT h.cgeneralhid) AS 总单据数
FROM IC_GENERAL_H h
INNER JOIN IC_GENERAL_B b
    ON h.cgeneralhid = b.cgeneralhid
    AND b.dr = 0
WHERE h.pk_corp = '1006'
    AND h.dr = 0
    AND h.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
    AND h.fbillflag >= 3
    AND h.dbilldate >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m-01')
GROUP BY DATE_FORMAT(h.dbilldate, '%Y-%m')
ORDER BY 年月;
