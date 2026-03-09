-- =====================================================
-- 报表15: 采购入库统计
-- 业务价值: 掌握采购到货情况，优化库存补货策略
-- MV依赖: 无（直接查询基表）
-- 更新频率: 每周
-- 说明: 基于IC_GENERAL_H出入库单据，筛选入库类型单据
-- =====================================================

-- =====================================================
-- 15.1 月度入库汇总
-- =====================================================
SELECT
    DATE_FORMAT(h.dbilldate, '%Y-%m') AS 年月,
    bt.billtypename AS 入库类型,
    COUNT(DISTINCT h.cgeneralhid) AS 入库单数,
    SUM(b.ninnum) AS 入库总数量
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
    AND b.ninnum > 0
    AND h.dbilldate >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH), '%Y-%m-01')
GROUP BY DATE_FORMAT(h.dbilldate, '%Y-%m'), bt.billtypename
ORDER BY 年月 DESC, 入库总数量 DESC;


-- =====================================================
-- 15.2 按商品入库统计 (本月)
-- =====================================================
SELECT
    inv.invcode AS 商品编码,
    inv.invname AS 商品名称,
    inv.invpinpai AS 品牌,
    inv.width AS 大类,
    inv.length AS 品类,
    SUM(b.ninnum) AS 入库数量,
    COUNT(DISTINCT h.cgeneralhid) AS 入库单数
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
    AND b.ninnum > 0
    AND h.dbilldate >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
    AND SUBSTR(inv.invcode, 1, 2) != '98'
GROUP BY inv.invcode, inv.invname, inv.invpinpai, inv.width, inv.length
ORDER BY 入库数量 DESC;


-- =====================================================
-- 15.3 按仓库入库统计 (本月)
-- =====================================================
SELECT
    stor.storname AS 仓库名称,
    bt.billtypename AS 入库类型,
    COUNT(DISTINCT h.cgeneralhid) AS 入库单数,
    SUM(b.ninnum) AS 入库数量
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
    AND b.ninnum > 0
    AND h.dbilldate >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
GROUP BY stor.storname, bt.billtypename
ORDER BY 入库数量 DESC;
