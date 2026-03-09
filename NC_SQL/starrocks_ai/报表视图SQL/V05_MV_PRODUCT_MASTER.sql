-- =====================================================
-- 物化视图5: 商品主数据视图 (MV_PRODUCT_MASTER)
-- 用途: 商品完整信息(含成本)
-- 刷新策略: 每日定时 (DEFERRED ASYNC EVERY 1 DAY)
-- 服务报表: 所有涉及商品信息的报表
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS MV_PRODUCT_MASTER
COMMENT '商品主数据视图 - 含成本与供应商信息'
DISTRIBUTED BY HASH(商品主键) BUCKETS 32
ORDER BY (商品编码, 品牌)
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400"
)
AS
SELECT
    inv.pk_invbasdoc AS 商品主键,
    invman.pk_invmandoc AS 商品管理主键,

    inv.invcode AS 商品编码,
    inv.invname AS 商品名称,
    inv.invbarcode AS 条形码,
    inv.mnecode AS 助记码,

    inv.invpinpai AS 品牌,
    inv.width AS 大类,
    inv.length AS 品类,
    inv.height AS 小类,
    inv.invspec AS 规格,
    inv.invtype AS 型号,

    inv.setpartsflag AS 是否成套件,
    inv.isretail AS 是否零售,
    CASE
        WHEN inv.sealflag IS NOT NULL AND LENGTH(TRIM(inv.sealflag)) > 0 THEN 'Y'
        ELSE 'N'
    END AS 是否封存,

    invman.refsaleprice AS 参考售价,
    invman.lowestprice AS 最低售价,
    invman.maxprice AS 最高限价,

    gl.nabprice AS 结存单价,
    gl.nmonthprice AS 平均单价,
    gl.nplanedprice AS 计划单价,
    gl.caccountmonth AS 会计月份,

    gl.nabnum AS 结存数量,
    gl.nabmny AS 结存金额,

    supplier.pk_cubasdoc AS 主供应商主键,
    supplier.custname AS 主供应商名称,

    invman.memo AS 备注

FROM
    BD_INVBASDOC inv
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
                MAX(caccountmonth) AS max_month
            FROM IA_GENERALLEDGER
            WHERE dr = 0
                AND pk_corp = '1006'
                AND caccountmonth != '00'
            GROUP BY cinventoryid
        ) gl2 ON gl1.cinventoryid = gl2.cinventoryid
            AND gl1.caccountmonth = gl2.max_month
        WHERE gl1.dr = 0
            AND gl1.pk_corp = '1006'
    ) gl ON invman.pk_invmandoc = gl.cinventoryid
    LEFT JOIN BD_CUMANDOC suppman
        ON invman.pk_cumandoc = suppman.pk_cumandoc
        AND suppman.pk_corp = '1006'
        AND suppman.dr = 0
    LEFT JOIN BD_CUBASDOC supplier
        ON suppman.pk_cubasdoc = supplier.pk_cubasdoc
        AND supplier.dr = 0
WHERE
    inv.dr = 0
    AND SUBSTR(inv.invcode, 1, 2) != '98';
