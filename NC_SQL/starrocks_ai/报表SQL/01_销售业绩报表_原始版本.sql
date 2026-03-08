-- =====================================================
-- 报表1: 销售业绩报表 (不使用物化视图的原始版本)
-- 业务价值: 监控销售业绩,支持经营决策
-- 注意: 此版本查询性能较慢,建议使用物化视图版本
-- =====================================================

-- =====================================================
-- 1.1 销售日报 (原始查询)
-- =====================================================
SELECT 
    DATE_FORMAT(sq.dmakedate, '%Y-%m-%d') AS 日期,
    dept.deptname AS 部门名称,
    psn.psnname AS 业务员姓名,
    invbas.invpinpai AS 品牌,
    invbas.width AS 大类,
    invbas.length AS 品类,
    -- 核心指标
    SUM(sq.noutnum) AS 销售数量,
    ROUND(SUM(
        CASE 
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
            ELSE
                ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
        END
    ), 2) AS 销售流水,
    ROUND(SUM(sq.ncostmny), 2) AS 销售成本,
    ROUND(SUM(
        CASE 
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2) - sq.ncostmny
            ELSE
                ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2) - sq.ncostmny
        END
    ), 2) AS 毛利,
    -- 毛利率
    CASE 
        WHEN SUM(
            CASE 
                WHEN sq.blargessflag = 'Y' THEN 0
                WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                    ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
                ELSE
                    ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
            END
        ) = 0 THEN 0
        ELSE ROUND(
            SUM(
                CASE 
                    WHEN sq.blargessflag = 'Y' THEN 0
                    WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                        ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2) - sq.ncostmny
                    ELSE
                        ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2) - sq.ncostmny
                END
            ) / SUM(
                CASE 
                    WHEN sq.blargessflag = 'Y' THEN 0
                    WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                        ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
                    ELSE
                        ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
                END
            ) * 100, 2
        )
    END AS 毛利率,
    COUNT(DISTINCT cumbase.pk_cubasdoc) AS 客户数
FROM 
    SO_SQUAREDETAIL sq
    INNER JOIN BD_INVMANDOC invman 
        ON sq.cinventoryid = invman.pk_invmandoc
        AND invman.pk_corp = '1006'
        AND invman.dr = 0
    INNER JOIN BD_INVBASDOC invbas 
        ON invman.pk_invbasdoc = invbas.pk_invbasdoc
        AND invbas.dr = 0
    LEFT JOIN BD_CUMANDOC cuman 
        ON sq.ccustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006'
        AND cuman.dr = 0
    LEFT JOIN BD_CUBASDOC cumbase 
        ON cuman.pk_cubasdoc = cumbase.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PSNDOC psn 
        ON sq.cemployeeid = psn.pk_psndoc
        AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept 
        ON sq.cdeptid = dept.pk_deptdoc
        AND dept.dr = 0
WHERE 
    sq.pk_corp = '1006'
    AND sq.dr = 0
    AND sq.dmakedate >= DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
    AND SUBSTR(invbas.invcode, 1, 2) != '98'
    AND invbas.width IN ('兼容', '原装', '打印机', '电脑PC')
GROUP BY 
    DATE_FORMAT(sq.dmakedate, '%Y-%m-%d'),
    dept.deptname,
    psn.psnname,
    invbas.invpinpai,
    invbas.width,
    invbas.length
ORDER BY 
    日期 DESC,
    销售流水 DESC;


-- =====================================================
-- 1.2 销售月报 (原始查询)
-- =====================================================
SELECT 
    DATE_FORMAT(sq.dmakedate, '%Y-%m') AS 年月,
    dept.deptname AS 部门名称,
    psn.psnname AS 业务员姓名,
    invbas.invpinpai AS 品牌,
    invbas.width AS 大类,
    invbas.length AS 品类,
    -- 核心指标
    SUM(sq.noutnum) AS 销售数量,
    ROUND(SUM(
        CASE 
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
            ELSE
                ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
        END
    ), 2) AS 销售流水,
    ROUND(SUM(sq.ncostmny), 2) AS 销售成本,
    ROUND(SUM(
        CASE 
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2) - sq.ncostmny
            ELSE
                ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2) - sq.ncostmny
        END
    ), 2) AS 毛利,
    -- 毛利率
    CASE 
        WHEN SUM(
            CASE 
                WHEN sq.blargessflag = 'Y' THEN 0
                WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                    ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
                ELSE
                    ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
            END
        ) = 0 THEN 0
        ELSE ROUND(
            SUM(
                CASE 
                    WHEN sq.blargessflag = 'Y' THEN 0
                    WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                        ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2) - sq.ncostmny
                    ELSE
                        ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2) - sq.ncostmny
                END
            ) / SUM(
                CASE 
                    WHEN sq.blargessflag = 'Y' THEN 0
                    WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                        ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
                    ELSE
                        ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
                END
            ) * 100, 2
        )
    END AS 毛利率,
    COUNT(DISTINCT cumbase.pk_cubasdoc) AS 客户数
FROM 
    SO_SQUAREDETAIL sq
    INNER JOIN BD_INVMANDOC invman 
        ON sq.cinventoryid = invman.pk_invmandoc
        AND invman.pk_corp = '1006'
        AND invman.dr = 0
    INNER JOIN BD_INVBASDOC invbas 
        ON invman.pk_invbasdoc = invbas.pk_invbasdoc
        AND invbas.dr = 0
    LEFT JOIN BD_CUMANDOC cuman 
        ON sq.ccustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006'
        AND cuman.dr = 0
    LEFT JOIN BD_CUBASDOC cumbase 
        ON cuman.pk_cubasdoc = cumbase.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PSNDOC psn 
        ON sq.cemployeeid = psn.pk_psndoc
        AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept 
        ON sq.cdeptid = dept.pk_deptdoc
        AND dept.dr = 0
WHERE 
    sq.pk_corp = '1006'
    AND sq.dr = 0
    AND sq.dmakedate >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
    AND SUBSTR(invbas.invcode, 1, 2) != '98'
    AND invbas.width IN ('兼容', '原装', '打印机', '电脑PC')
GROUP BY 
    DATE_FORMAT(sq.dmakedate, '%Y-%m'),
    dept.deptname,
    psn.psnname,
    invbas.invpinpai,
    invbas.width,
    invbas.length
ORDER BY 
    年月 DESC,
    销售流水 DESC;
