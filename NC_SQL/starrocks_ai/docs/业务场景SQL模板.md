# 业务场景SQL模板集

> 本文档整合了各业务场景的标准SQL查询模板，直接复用或微调即可使用。  
> 编码规则详见 `docs/SQL编码规范.md`，表关系详见 `docs/数据库表关系图.md`。

---

## 一、库存查询

### 1.1 基础库存查询

```sql
SELECT
    stor.storcode AS 仓库编码,
    stor.storname AS 仓库名称,
    inv.invcode AS 存货编码,
    inv.invname AS 存货名称,
    inv.invpinpai AS 品牌,
    inv.width AS 大类,
    inv.length AS 品类,
    inv.height AS 小类,
    inv.invspec AS 规格,
    inv.invtype AS 型号,
    oh.nonhandnum AS 结存数量,
    oh.nonhandastnum AS 结存辅数量
FROM 
    IC_ONHANDNUM oh
    INNER JOIN BD_INVBASDOC inv 
        ON oh.cinvbasid = inv.pk_invbasdoc AND inv.dr = 0
    INNER JOIN BD_STORDOC stor 
        ON oh.cwarehouseid = stor.pk_stordoc AND stor.dr = 0
WHERE 
    oh.pk_corp = '1006' AND oh.dr = 0
    AND oh.nonhandnum <> 0
ORDER BY stor.storcode, inv.invcode;
```

### 1.2 库存价值查询（含成本）

**成本单价优先级**：`nabprice`（结存单价）→ `noutmny/noutnum`（发出单价）→ `costprice`（参考成本）

```sql
SELECT
    stor.storname AS 仓库名称,
    inv.invcode AS 存货编码,
    inv.invname AS 存货名称,
    inv.invpinpai AS 品牌,
    inv.width AS 大类,
    oh.nonhandnum AS 结存数量,
    COALESCE(
        gl.nabprice,
        CASE WHEN gl.noutnum = 0 THEN 0 ELSE ROUND(gl.noutmny / gl.noutnum, 2) END,
        invman.costprice,
        0
    ) AS 成本单价,
    ROUND(
        oh.nonhandnum * COALESCE(
            gl.nabprice,
            CASE WHEN gl.noutnum = 0 THEN 0 ELSE ROUND(gl.noutmny / gl.noutnum, 2) END,
            0
        ), 2
    ) AS 库存金额
FROM 
    IC_ONHANDNUM oh
    INNER JOIN BD_INVBASDOC inv ON oh.cinvbasid = inv.pk_invbasdoc AND inv.dr = 0
    INNER JOIN BD_STORDOC stor ON oh.cwarehouseid = stor.pk_stordoc AND stor.dr = 0
    INNER JOIN BD_INVMANDOC invman ON oh.cinventoryid = invman.pk_invmandoc
        AND invman.pk_corp = '1006' AND invman.dr = 0
    LEFT JOIN IA_GENERALLEDGER gl ON oh.cinventoryid = gl.cinventoryid 
        AND oh.ccalbodyid = gl.crdcenterid  -- 必须双字段关联
        AND gl.dr = 0 AND gl.caccountmonth <> '00'  -- 排除期初数据
WHERE 
    oh.pk_corp = '1006' AND oh.dr = 0
    AND oh.nonhandnum > 0
ORDER BY stor.storcode, inv.invcode;
```

### 1.3 按仓库/品牌汇总库存

```sql
-- 按仓库
SELECT
    stor.storname AS 仓库名称,
    COUNT(DISTINCT oh.cinvbasid) AS 存货品种数,
    SUM(oh.nonhandnum) AS 总库存数量,
    SUM(ROUND(oh.nonhandnum * COALESCE(gl.nabprice, 0), 2)) AS 总库存金额
FROM IC_ONHANDNUM oh
    INNER JOIN BD_STORDOC stor ON oh.cwarehouseid = stor.pk_stordoc AND stor.dr = 0
    LEFT JOIN IA_GENERALLEDGER gl ON oh.cinventoryid = gl.cinventoryid 
        AND oh.ccalbodyid = gl.crdcenterid AND gl.dr = 0
WHERE oh.pk_corp = '1006' AND oh.dr = 0 AND oh.nonhandnum > 0
GROUP BY stor.storname
ORDER BY 总库存金额 DESC;

-- 按品牌
SELECT
    inv.invpinpai AS 品牌, inv.width AS 大类,
    COUNT(DISTINCT inv.pk_invbasdoc) AS 品种数,
    SUM(oh.nonhandnum) AS 总数量,
    SUM(ROUND(oh.nonhandnum * COALESCE(gl.nabprice, 0), 2)) AS 总金额
FROM IC_ONHANDNUM oh
    INNER JOIN BD_INVBASDOC inv ON oh.cinvbasid = inv.pk_invbasdoc AND inv.dr = 0
    LEFT JOIN IA_GENERALLEDGER gl ON oh.cinventoryid = gl.cinventoryid 
        AND oh.ccalbodyid = gl.crdcenterid AND gl.dr = 0
WHERE oh.pk_corp = '1006' AND oh.dr = 0 AND oh.nonhandnum > 0
GROUP BY inv.invpinpai, inv.width
ORDER BY 总金额 DESC;
```

---

## 二、销售查询

### 2.1 销售明细查询（发票流程）

```sql
SELECT
    ii.vreceiptcode AS 发票号,
    od.vreceiptcode AS 订单号,
    od.dbilldate AS 单据日期,
    YEAR(od.dbilldate) AS 年份,
    MONTH(od.dbilldate) AS 月份,
    inv.invcode AS 商品编码,
    inv.invname AS 商品名称,
    inv.invpinpai AS 品牌,
    inv.width AS 大类,
    cub.custcode AS 客户编码,
    cub.custname AS 客户名称,
    psn.psnname AS 业务员姓名,
    dept.deptname AS 部门名称,
    fdept.deptname AS 大部门,
    ib.nnumber AS 数量,
    CASE WHEN ib.blargessflag = 'N' THEN ib.nsummny ELSE 0 END AS 金额小计
FROM 
    SO_SALEINVOICE_B ib
    INNER JOIN SO_SALEINVOICE ii ON ib.csaleid = ii.csaleid AND ii.dr = 0
    INNER JOIN BD_INVBASDOC inv ON ib.cinvbasdocid = inv.pk_invbasdoc AND inv.dr = 0
    LEFT JOIN SO_SALE od ON ib.coriginalbillcode = od.vreceiptcode
        AND od.pk_corp = '1006' AND od.dr = 0
    LEFT JOIN BD_CUMANDOC cum ON od.creceiptcorpid = cum.pk_cumandoc
        AND cum.pk_corp = '1006' AND cum.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON cum.pk_cubasdoc = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN BD_PSNDOC psn ON od.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON od.cdeptid = dept.pk_deptdoc AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept ON dept.pk_fathedept = fdept.pk_deptdoc AND fdept.dr = 0
WHERE 
    ib.pk_corp = '1006' AND ib.dr = 0
ORDER BY od.dbilldate DESC, ii.vreceiptcode;
```

### 2.2 销售毛利分析（结算流程）

```sql
SELECT 
    sq.dmakedate AS 日期,
    dept.deptname AS 部门,
    psn.psnname AS 业务员,
    cubas.custname AS 客户名称,
    btp.businame AS 业务类型,
    invbas.invname AS 存货名称,
    invbas.invpinpai AS 品牌,
    invbas.width AS 大类,
    invbas.length AS 品类,
    sq.blargessflag AS 是否赠品,
    SUM(sq.noutnum) AS 数量,
    SUM(
        CASE
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
            ELSE ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
        END
    ) AS 流水,
    SUM(sq.ncostmny) AS 成本,
    SUM(
        CASE
            WHEN sq.blargessflag = 'Y' THEN 0
            WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
                ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
            ELSE ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
        END
    ) - SUM(sq.ncostmny) AS 毛利
FROM 
    SO_SQUAREDETAIL sq
    INNER JOIN BD_INVMANDOC invman ON sq.cinventoryid = invman.pk_invmandoc
        AND invman.pk_corp = '1006' AND invman.dr = 0
    INNER JOIN BD_INVBASDOC invbas ON invman.pk_invbasdoc = invbas.pk_invbasdoc
        AND invbas.dr = 0
        AND (invbas.invcode = '9808' OR invbas.invcode = '9809' 
             OR invbas.invcode = '9813' OR SUBSTR(invbas.invcode, 1, 2) <> '98')
    INNER JOIN BD_DEPTDOC dept ON sq.cdeptid = dept.pk_deptdoc AND dept.dr = 0
    INNER JOIN BD_PSNDOC psn ON sq.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_CUMANDOC cuman ON sq.ccustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006' AND cuman.dr = 0
    LEFT JOIN BD_CUBASDOC cubas ON cuman.pk_cubasdoc = cubas.pk_cubasdoc AND cubas.dr = 0
    LEFT JOIN BD_BUSITYPE btp ON sq.cbiztype = btp.pk_busitype AND btp.dr = 0
WHERE 
    sq.pk_corp = '1006' AND sq.dr = 0
    AND btp.businame <> '放货销售'
GROUP BY 
    sq.dmakedate, dept.deptname, psn.psnname, cubas.custname,
    btp.businame, invbas.invname, invbas.invpinpai,
    sq.blargessflag, invbas.width, invbas.length
ORDER BY sq.dmakedate DESC, 毛利 DESC;
```

### 2.3 按部门/业务员汇总销售

```sql
-- 按业务员汇总（含毛利率）
SELECT 
    psn.psnname AS 业务员,
    dept.deptname AS 部门,
    COUNT(DISTINCT sq.ccustomerid) AS 客户数,
    SUM(sq.noutnum) AS 总数量,
    SUM(CASE WHEN sq.blargessflag <> 'Y' THEN sq.noriginalcurmny ELSE 0 END) AS 总销售额,
    SUM(sq.ncostmny) AS 总成本,
    SUM(CASE WHEN sq.blargessflag <> 'Y' THEN sq.noriginalcurmny ELSE 0 END) 
        - SUM(sq.ncostmny) AS 总毛利,
    CASE 
        WHEN SUM(CASE WHEN sq.blargessflag <> 'Y' THEN sq.noriginalcurmny ELSE 0 END) = 0 THEN 0
        ELSE ROUND(
            (SUM(CASE WHEN sq.blargessflag <> 'Y' THEN sq.noriginalcurmny ELSE 0 END) - SUM(sq.ncostmny)) 
            / SUM(CASE WHEN sq.blargessflag <> 'Y' THEN sq.noriginalcurmny ELSE 0 END) * 100, 2
        )
    END AS 毛利率
FROM SO_SQUAREDETAIL sq
    INNER JOIN BD_PSNDOC psn ON sq.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON sq.cdeptid = dept.pk_deptdoc AND dept.dr = 0
WHERE sq.pk_corp = '1006' AND sq.dr = 0
GROUP BY psn.psnname, dept.deptname
ORDER BY 总销售额 DESC;
```

---

## 三、客户信息查询

### 3.1 完整客户信息（含账期+信用+地区）

```sql
SELECT
    cumbase.pk_cubasdoc AS 客户主键,
    cumbase.custcode AS 客户编码,
    cumbase.custname AS 客户名称,
    cumbase.createtime AS 创建日期,
    cumbase.freecustflag AS 是否散户,
    cumbase.isconnflag AS 是否渠道成员,
    CASE WHEN cumbase.def3 = '0001C11000000012TJ3X' THEN 'Y' ELSE 'N' END AS 商桥,
    CASE WHEN cuman.sealflag IS NOT NULL AND LENGTH(TRIM(cuman.sealflag)) > 0 
         THEN 'Y' ELSE 'N' END AS 是否封存,
    cuman.custflag AS 客商属性,
    cumbase.linkman1 AS 联系人1,
    cumbase.mobilephone1 AS 联系电话1,
    cumbase.conaddr AS 地址,
    cumbase.bp1 AS QQ微信,
    cumbase.bp3 AS 客户来源,
    cumbase.def10 AS 开票信息,
    cuman.innerctldays AS 信用天数,
    term.termname AS 付款协议,
    redit.nlimitmny AS 信用额度,
    redits.nlimitmny AS 临时信用额度,
    psn.psnname AS 业务员姓名,
    dept.deptname AS 部门名称,
    fdept.deptname AS 大部门,
    dq.sf AS 省, dq.cs AS 市,
    cuman.memo AS 备注
FROM 
    BD_CUMANDOC cuman
    INNER JOIN BD_CUBASDOC cumbase ON cumbase.pk_cubasdoc = cuman.pk_cubasdoc AND cumbase.dr = 0
    LEFT JOIN BD_PAYTERM term ON cuman.pk_payterm = term.pk_payterm
        AND term.pk_corp = '1006' AND term.dr = 0
    LEFT JOIN BD_PSNDOC psn ON psn.pk_psndoc = cuman.pk_resppsn1 AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON cuman.pk_respdept1 = dept.pk_deptdoc AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept ON dept.pk_fathedept = fdept.pk_deptdoc AND fdept.dr = 0
    LEFT JOIN (
        SELECT cl.pk_areacl, c.areaclname AS sf, cl.areaclname AS cs
        FROM BD_AREACL c INNER JOIN BD_AREACL cl ON c.pk_areacl = cl.pk_fatherarea
    ) dq ON cumbase.pk_areacl = dq.pk_areacl
    LEFT JOIN SO_CUCREDIT redit ON cumbase.pk_cubasdoc = redit.pk_cubasdoc
        AND redit.climittypeid = '0001A110000000002EXU' AND redit.vcredittypename = '2' AND redit.dr = 0
    LEFT JOIN SO_CUCREDIT redits ON cumbase.pk_cubasdoc = redits.pk_cubasdoc
        AND redits.climittypeid = '0001A110000000002EXV' AND redits.vcredittypename = '2' AND redits.dr = 0
WHERE 
    cuman.pk_corp = '1006' AND cuman.dr = 0
    AND cuman.custflag IN ('0', '2')
ORDER BY cumbase.custcode;
```

---

## 四、应收账款查询

### 4.1 应收账龄查询

```sql
SELECT
    dept.deptname AS 部门名称,
    fdept.deptname AS 大部门,
    psn.psnname AS 业务员姓名,
    cub.custcode AS 客户编码,
    cub.custname AS 客户名称,
    CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END AS 单据账期,
    ss.dbilldate AS 单据日期,
    CASE WHEN so.vreceiptcode IS NULL THEN sy.vreceiptcode ELSE so.vreceiptcode END AS 单号,
    DATE_ADD(
        CAST(ss.dbilldate AS DATE),
        INTERVAL CAST(CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END AS INT) DAY
    ) AS 预计结算日期,
    DATEDIFF(
        CURRENT_DATE(),
        DATE_ADD(CAST(ss.dbilldate AS DATE),
            INTERVAL CAST(CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END AS INT) DAY)
    ) AS 超期天数,
    SUM(sb.nsummny) AS 金额
FROM 
    SO_SQUARE ss
    INNER JOIN SO_SQUARE_B sb ON ss.csaleid = sb.csaleid AND sb.dr = 0
        AND IFNULL(sb.noutnum, 0) <> IFNULL(sb.nbalancenum, 0)  -- 未结算完成
        AND IFNULL(sb.blargessflag, 'N') = 'N'
    LEFT JOIN SO_SALE so ON sb.csourcebillid = so.csaleid
        AND so.pk_corp = '1006' AND so.dr = 0
    LEFT JOIN SO_APPLY sy ON sb.csourcebillid = sy.pk_apply AND sy.dr = 0
    LEFT JOIN BD_PAYTERM m ON ss.ctermprotocolid = m.pk_payterm
        AND m.pk_corp = '1006' AND m.dr = 0
    LEFT JOIN BD_CUMANDOC cum ON ss.ccustomerid = cum.pk_cumandoc
        AND cum.pk_corp = '1006' AND cum.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON cum.pk_cubasdoc = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN BD_PSNDOC psn ON ss.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON ss.cdeptid = dept.pk_deptdoc AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept ON dept.pk_fathedept = fdept.pk_deptdoc AND fdept.dr = 0
WHERE 
    ss.pk_corp = '1006' AND ss.dr = 0
GROUP BY 
    dept.deptname, fdept.deptname, psn.psnname,
    cub.pk_cubasdoc, cub.custcode, cub.custname,
    m.termid, ss.dbilldate, so.vreceiptcode, sy.vreceiptcode, ss.vdef11, ss.vdef5
ORDER BY dept.deptname, cub.custname, ss.dbilldate;
```

### 4.2 账龄区间分析

```sql
SELECT
    cub.custname AS 客户名称,
    SUM(CASE WHEN DATEDIFF(CURRENT_DATE(),
        DATE_ADD(CAST(ss.dbilldate AS DATE), INTERVAL CAST(COALESCE(m.termid, '0') AS INT) DAY)
    ) <= 0 THEN sb.nsummny ELSE 0 END) AS 未到期,
    SUM(CASE WHEN DATEDIFF(CURRENT_DATE(),
        DATE_ADD(CAST(ss.dbilldate AS DATE), INTERVAL CAST(COALESCE(m.termid, '0') AS INT) DAY)
    ) BETWEEN 1 AND 30 THEN sb.nsummny ELSE 0 END) AS 超期1到30天,
    SUM(CASE WHEN DATEDIFF(CURRENT_DATE(),
        DATE_ADD(CAST(ss.dbilldate AS DATE), INTERVAL CAST(COALESCE(m.termid, '0') AS INT) DAY)
    ) BETWEEN 31 AND 60 THEN sb.nsummny ELSE 0 END) AS 超期31到60天,
    SUM(CASE WHEN DATEDIFF(CURRENT_DATE(),
        DATE_ADD(CAST(ss.dbilldate AS DATE), INTERVAL CAST(COALESCE(m.termid, '0') AS INT) DAY)
    ) BETWEEN 61 AND 90 THEN sb.nsummny ELSE 0 END) AS 超期61到90天,
    SUM(CASE WHEN DATEDIFF(CURRENT_DATE(),
        DATE_ADD(CAST(ss.dbilldate AS DATE), INTERVAL CAST(COALESCE(m.termid, '0') AS INT) DAY)
    ) > 90 THEN sb.nsummny ELSE 0 END) AS 超期90天以上,
    SUM(sb.nsummny) AS 应收总额
FROM SO_SQUARE ss
    INNER JOIN SO_SQUARE_B sb ON ss.csaleid = sb.csaleid AND sb.dr = 0
        AND IFNULL(sb.noutnum, 0) <> IFNULL(sb.nbalancenum, 0)
        AND IFNULL(sb.blargessflag, 'N') = 'N'
    LEFT JOIN BD_PAYTERM m ON ss.ctermprotocolid = m.pk_payterm
        AND m.pk_corp = '1006' AND m.dr = 0
    LEFT JOIN BD_CUMANDOC cum ON ss.ccustomerid = cum.pk_cumandoc
        AND cum.pk_corp = '1006' AND cum.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON cum.pk_cubasdoc = cub.pk_cubasdoc AND cub.dr = 0
WHERE ss.pk_corp = '1006' AND ss.dr = 0
GROUP BY cub.custname
ORDER BY 应收总额 DESC;
```

---

## 五、成本查询

### 5.1 存货成本价格对比

```sql
SELECT
    inv.invcode AS 存货编码,
    inv.invname AS 存货名称,
    gl.nabprice AS 结存单价,
    gl.nmonthprice AS 平均单价,
    gl.nplanedprice AS 计划单价,
    CASE WHEN gl.noutnum = 0 THEN 0 ELSE ROUND(gl.noutmny / gl.noutnum, 2) END AS 发出单价,
    invman.costprice AS 参考成本,
    invman.refsaleprice AS 参考售价,
    invman.lowestprice AS 最低售价,
    invman.maxprice AS 最高限价,
    COALESCE(
        gl.nabprice,
        CASE WHEN gl.noutnum = 0 THEN 0 ELSE ROUND(gl.noutmny / gl.noutnum, 2) END,
        invman.costprice, 0
    ) AS 推荐成本单价
FROM 
    BD_INVBASDOC inv
    INNER JOIN BD_INVMANDOC invman ON inv.pk_invbasdoc = invman.pk_invbasdoc
        AND invman.pk_corp = '1006' AND invman.dr = 0
    LEFT JOIN IA_GENERALLEDGER gl ON invman.pk_invmandoc = gl.cinventoryid
        AND gl.dr = 0 AND gl.caccountmonth <> '00'
WHERE inv.dr = 0
ORDER BY inv.invcode;
```

---

## 六、日期与账期处理

### 6.1 StarRocks 日期函数速查

| 函数 | 用途 | 示例 |
|------|------|------|
| `CAST(x AS DATE)` | 字符串转日期 | `CAST(dbilldate AS DATE)` |
| `DATE_ADD(d, INTERVAL n DAY)` | 日期加天数 | `DATE_ADD(CAST(dbilldate AS DATE), INTERVAL 30 DAY)` |
| `DATE_SUB(d, INTERVAL n DAY)` | 日期减天数 | `DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)` |
| `DATEDIFF(d1, d2)` | 日期差（天） | `DATEDIFF(CURRENT_DATE(), 预计结算日期)` |
| `YEAR(d)` / `MONTH(d)` / `DAY(d)` | 提取年/月/日 | `YEAR(dbilldate)` |
| `QUARTER(d)` / `WEEK(d)` | 提取季度/周 | `QUARTER(dbilldate)` |
| `DATE_FORMAT(d, fmt)` | 日期格式化 | `DATE_FORMAT(dbilldate, '%Y-%m')` |
| `CURRENT_DATE()` / `NOW()` | 当前日期/时间 | `WHERE dbilldate >= CURRENT_DATE() - INTERVAL 30 DAY` |

### 6.2 账期天数处理

```sql
-- termid = '01' 表示0天，必须特殊处理
CAST(
    CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END 
    AS INT
)

-- 预计结算日期 = 单据日期 + 账期天数
DATE_ADD(
    CAST(ss.dbilldate AS DATE),
    INTERVAL CAST(CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END AS INT) DAY
)

-- 超期天数 = 当前日期 - 预计结算日期（正数=已超期，负数=未到期）
DATEDIFF(CURRENT_DATE(), 预计结算日期)
```

### 6.3 常用日期范围查询

```sql
-- 本月
WHERE YEAR(dbilldate) = YEAR(CURRENT_DATE()) AND MONTH(dbilldate) = MONTH(CURRENT_DATE())

-- 本年
WHERE YEAR(dbilldate) = YEAR(CURRENT_DATE())

-- 最近N天
WHERE dbilldate >= CURRENT_DATE() - INTERVAL 30 DAY

-- 即将到期（未来10天）
WHERE 预计结算日期 BETWEEN CURRENT_DATE() AND CURRENT_DATE() + INTERVAL 10 DAY

-- 已超期
WHERE 预计结算日期 < CURRENT_DATE()
```

### 6.4 按时间维度汇总

```sql
-- 按月
SELECT YEAR(d) AS 年份, MONTH(d) AS 月份, DATE_FORMAT(d, '%Y-%m') AS 年月, SUM(金额) AS 总金额
FROM ... GROUP BY YEAR(d), MONTH(d), DATE_FORMAT(d, '%Y-%m') ORDER BY 年份, 月份;

-- 按季度
SELECT YEAR(d) AS 年份, QUARTER(d) AS 季度, SUM(金额) AS 总金额
FROM ... GROUP BY YEAR(d), QUARTER(d) ORDER BY 年份, 季度;
```

---

## 七、聚合与分析技巧

### 7.1 GROUP BY 规范

SELECT 中所有非聚合字段 **必须** 出现在 GROUP BY 中。

### 7.2 HAVING（分组后过滤）

```sql
-- 销售额大于100万的客户
SELECT cub.custname, SUM(金额) AS 总销售额
FROM ... GROUP BY cub.custname
HAVING SUM(金额) > 1000000 ORDER BY 总销售额 DESC;
```

### 7.3 条件聚合（CASE WHEN + SUM）

```sql
-- 赠品/非赠品分别统计
SUM(CASE WHEN blargessflag = 'Y' THEN nsummny ELSE 0 END) AS 赠品金额,
SUM(CASE WHEN blargessflag = 'N' THEN nsummny ELSE 0 END) AS 销售金额

-- 按账龄区间统计（见4.2模板）
```

### 7.4 占比计算

```sql
SELECT 
    dept.deptname AS 部门,
    SUM(金额) AS 部门金额,
    ROUND(SUM(金额) / (SELECT SUM(金额) FROM ...) * 100, 2) AS 占比
FROM ... GROUP BY dept.deptname ORDER BY 部门金额 DESC;
```

### 7.5 排名查询

```sql
-- 窗口函数（推荐）
SELECT 部门, SUM(金额) AS 总金额, RANK() OVER (ORDER BY SUM(金额) DESC) AS 排名
FROM ... GROUP BY 部门;

-- TOP N
SELECT ... FROM ... GROUP BY ... ORDER BY 金额 DESC LIMIT 10;
```

---

## 八、特殊字段处理速查

| 字段 | 表 | 含义 | 处理方式 |
|------|-----|------|---------|
| `blargessflag` | SO_SQUAREDETAIL等 | 是否赠品 | `'Y'`=赠品→金额置0；`IFNULL(blargessflag,'N')='N'` |
| `custflag` | BD_CUMANDOC | 客商属性 | `IN ('0','2')`=客户；`='1'`=供应商 |
| `sealflag` | BD_CUMANDOC/INVBASDOC/STORDOC | 封存标志 | 存货/仓库：`<>'1'`；客商：`IS NULL OR LENGTH(TRIM())=0` |
| `def3` | BD_CUBASDOC | 商桥标识 | `='0001C11000000012TJ3X'` 表示已开通 |
| `termid` | BD_PAYTERM | 账期天数 | `'01'`→转为`'0'`；必须 `CAST(... AS INT)` |
| `climittypeid` | SO_CUCREDIT | 信用类型 | `EXU`=可欠款；`EXV`=临时；配合 `vcredittypename='2'` |
| `coriginalbillcode` | SO_SALEINVOICE_B | 源头单号 | `LIKE 'TH%'` 或 `'3U%'` → 退货单 |
| `invcode` | BD_INVBASDOC | 存货编码 | 98开头=特殊存货（保留9808/9809/9813） |
| `vbodydef5` | SO_SQUAREDETAIL | 自定义单价 | 非0时优先使用此价格计算销售流水 |
| `noutnum`/`nbalancenum` | SO_SQUARE_B | 实发/累计结算 | `IFNULL(noutnum,0)<>IFNULL(nbalancenum,0)` → 未结算完成 |
| `fstatusflag` | TO_BILL | 调拨状态 | 1自由/2保存/4审批中/5已审批/7关闭 |
| `fbillflag` | IC_GENERAL_H | 出入库状态 | `>=3` 表示已审批 |
| `caccountmonth` | IA_GENERALLEDGER | 会计月份 | `<>'00'` 排除期初数据 |

---

## 九、性能优化技巧

| 技巧 | 示例 |
|------|------|
| EXISTS 代替 IN | `WHERE EXISTS (SELECT 1 FROM ... WHERE ...)` 优于 `WHERE pk IN (SELECT ...)` |
| 避免 SELECT * | 只查询需要的字段 |
| 避免 WHERE 中用函数 | `dbilldate >= '2024-01-01' AND dbilldate < '2025-01-01'` 优于 `YEAR(dbilldate)=2024` |
| UNION ALL 代替 UNION | 确认无重复时使用 UNION ALL |
| LIMIT 限制结果 | 大结果集加 `LIMIT 1000` |
| pk_corp 和 dr 放JOIN条件中 | 利用索引，在关联时就过滤 |

---

**编码规范**: `docs/SQL编码规范.md`  
**表关系详情**: `docs/数据库表关系图.md`  
**数据字典**: `docs/数据字典.md`
