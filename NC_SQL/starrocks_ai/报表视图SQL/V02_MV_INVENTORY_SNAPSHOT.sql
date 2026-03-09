-- =====================================================
-- 物化视图2: 库存快照表 (MV_INVENTORY_SNAPSHOT)
-- 用途: 库存监控和周转分析
-- 刷新策略: 每日定时 (DEFERRED ASYNC EVERY 1 DAY)
-- 服务报表: 库存监控、库存周转
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS MV_INVENTORY_SNAPSHOT
COMMENT '库存快照表 - 库存监控和周转分析'
DISTRIBUTED BY HASH(商品主键) BUCKETS 32
ORDER BY (仓库主键, 商品主键)
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400",
    "excluded_trigger_tables" = "BD_INVBASDOC,BD_STORDOC"
)
AS
SELECT
    oh.pk_onhandnum AS 现存量主键,

    stor.pk_stordoc AS 仓库主键,
    stor.storcode AS 仓库编码,
    stor.storname AS 仓库名称,

    inv.pk_invbasdoc AS 商品主键,
    inv.invcode AS 商品编码,
    inv.invname AS 商品名称,
    inv.invpinpai AS 品牌,
    inv.width AS 大类,
    inv.length AS 品类,
    inv.height AS 小类,

    oh.nonhandnum AS 结存数量,
    oh.nonhandastnum AS 结存辅数量,

    COALESCE(
        gl.nabprice,
        CASE
            WHEN gl.noutnum = 0 OR gl.noutnum IS NULL THEN 0
            ELSE ROUND(gl.noutmny / gl.noutnum, 2)
        END
    ) AS 结存单价,

    ROUND(
        oh.nonhandnum * COALESCE(
            gl.nabprice,
            CASE
                WHEN gl.noutnum = 0 OR gl.noutnum IS NULL THEN 0
                ELSE ROUND(gl.noutmny / gl.noutnum, 2)
            END
        ), 2
    ) AS 库存金额,

    gl.nmonthprice AS 平均单价,
    gl.nplanedprice AS 计划单价,
    gl.caccountmonth AS 会计月份,

    oh.ccalbodyid AS 库存组织主键

FROM
    IC_ONHANDNUM oh
    INNER JOIN BD_INVBASDOC inv
        ON oh.cinvbasid = inv.pk_invbasdoc
        AND inv.dr = 0
    INNER JOIN BD_STORDOC stor
        ON oh.cwarehouseid = stor.pk_stordoc
        AND stor.dr = 0
    LEFT JOIN BD_INVMANDOC invman
        ON inv.pk_invbasdoc = invman.pk_invbasdoc
        AND invman.pk_corp = '1006'
        AND invman.dr = 0
    LEFT JOIN (
        SELECT gl1.*
        FROM IA_GENERALLEDGER gl1
        INNER JOIN (
            SELECT
                cinventoryid,
                crdcenterid,
                MAX(caccountmonth) AS max_month
            FROM IA_GENERALLEDGER
            WHERE dr = 0
                AND pk_corp = '1006'
                AND caccountmonth != '00'
            GROUP BY cinventoryid, crdcenterid
        ) gl2 ON gl1.cinventoryid = gl2.cinventoryid
            AND gl1.crdcenterid = gl2.crdcenterid
            AND gl1.caccountmonth = gl2.max_month
        WHERE gl1.dr = 0
            AND gl1.pk_corp = '1006'
    ) gl ON invman.pk_invmandoc = gl.cinventoryid
        AND oh.ccalbodyid = gl.crdcenterid
WHERE
    oh.pk_corp = '1006'
    AND oh.dr = 0
    AND oh.nonhandnum != 0
    AND SUBSTR(inv.invcode, 1, 2) != '98';
