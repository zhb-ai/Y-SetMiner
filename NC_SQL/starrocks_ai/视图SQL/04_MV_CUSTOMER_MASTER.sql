-- =====================================================
-- 物化视图4: 客户主数据视图 (MV_CUSTOMER_MASTER)
-- 用途: 客户完整信息(含账期、信用额度)
-- 刷新策略: 每日定时 (DEFERRED ASYNC EVERY 1 DAY)
-- 服务报表: 所有涉及客户信息的报表
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS MV_CUSTOMER_MASTER
COMMENT '客户主数据视图 - 含账期与信用额度'
DISTRIBUTED BY HASH(客户主键) BUCKETS 32
ORDER BY (客户编码)
REFRESH DEFERRED ASYNC EVERY (INTERVAL 1 DAY)
PROPERTIES (
    "enable_spill" = "true",
    "mv_rewrite_staleness_second" = "86400"
)
AS
SELECT
    cumbase.pk_cubasdoc AS 客户主键,
    cuman.pk_cumandoc AS 客户管理主键,

    cumbase.custcode AS 客户编码,
    cumbase.custname AS 客户名称,
    cumbase.createtime AS 创建日期,
    cumbase.mnecode AS 助记码,

    cumbase.freecustflag AS 是否散户,
    cumbase.isconnflag AS 是否渠道成员,
    CASE
        WHEN cumbase.def3 = '0001C11000000012TJ3X' THEN 'Y'
        ELSE 'N'
    END AS 是否商桥,
    CASE
        WHEN cuman.sealflag IS NOT NULL AND LENGTH(TRIM(cuman.sealflag)) > 0 THEN 'Y'
        ELSE 'N'
    END AS 是否封存,
    cuman.custflag AS 客商属性,
    cuman.custstate AS 客商状态,

    cumbase.linkman1 AS 联系人1,
    cumbase.mobilephone1 AS 联系电话1,
    cumbase.phone1 AS 座机1,
    cumbase.linkman2 AS 联系人2,
    cumbase.mobilephone2 AS 联系电话2,
    cumbase.linkman3 AS 联系人3,
    cumbase.mobilephone3 AS 联系电话3,
    cumbase.bp1 AS QQ微信,
    cumbase.bp3 AS 客户来源,
    cumbase.conaddr AS 地址,

    cuman.innerctldays AS 信用天数,
    term.pk_payterm AS 付款协议主键,
    term.termname AS 付款协议名称,
    CAST(COALESCE(term.termid, '0') AS INT) AS 账期天数,

    redit.nlimitmny AS 信用额度,
    redits.nlimitmny AS 临时信用额度,
    COALESCE(redit.nlimitmny, 0) + COALESCE(redits.nlimitmny, 0) AS 总信用额度,

    psn.pk_psndoc AS 业务员主键,
    psn.psncode AS 业务员编码,
    psn.psnname AS 业务员姓名,
    dept.pk_deptdoc AS 部门主键,
    dept.deptname AS 部门名称,
    fdept.pk_deptdoc AS 大部门主键,
    fdept.deptname AS 大部门名称,

    dq.sf AS 省份,
    dq.cs AS 城市,

    cumbase.def10 AS 开票信息,
    cuman.memo AS 备注

FROM
    BD_CUMANDOC cuman
    INNER JOIN BD_CUBASDOC cumbase
        ON cumbase.pk_cubasdoc = cuman.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PAYTERM term
        ON cuman.pk_payterm = term.pk_payterm
        AND term.pk_corp = '1006'
        AND term.dr = 0
    LEFT JOIN BD_PSNDOC psn
        ON psn.pk_psndoc = cuman.pk_resppsn1
        AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept
        ON cuman.pk_respdept1 = dept.pk_deptdoc
        AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept
        ON dept.pk_fathedept = fdept.pk_deptdoc
        AND fdept.dr = 0
    LEFT JOIN (
        SELECT
            cl.pk_areacl,
            c.areaclname AS sf,
            cl.areaclname AS cs
        FROM BD_AREACL c
        INNER JOIN BD_AREACL cl
            ON c.pk_areacl = cl.pk_fatherarea
            AND c.dr = 0
            AND cl.dr = 0
    ) dq ON cumbase.pk_areacl = dq.pk_areacl
    LEFT JOIN SO_CUCREDIT redit
        ON cumbase.pk_cubasdoc = redit.pk_cubasdoc
        AND redit.climittypeid = '0001A110000000002EXU'
        AND redit.vcredittypename = '2'
        AND redit.dr = 0
    LEFT JOIN SO_CUCREDIT redits
        ON cumbase.pk_cubasdoc = redits.pk_cubasdoc
        AND redits.climittypeid = '0001A110000000002EXV'
        AND redits.vcredittypename = '2'
        AND redits.dr = 0
WHERE
    cuman.pk_corp = '1006'
    AND cuman.dr = 0
    AND cuman.custflag IN ('0', '2');
