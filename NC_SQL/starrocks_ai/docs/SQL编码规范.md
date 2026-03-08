# 用友NC数据仓库SQL编码规范（速查手册）

> 本文档是SQL编码层面的核心速查手册。  
> 完整开发流程请参考 `docs/SQL开发全流程规范.md`。  
> 表关系详情请参考 `docs/数据库表关系图.md`。

---

## 一、环境与基本规则

| 项目 | 值 |
|------|------|
| 数据库 | StarRocks |
| 源系统 | 用友NC ERP |
| 公司主键 | `pk_corp = '1006'` |
| 删除标志 | `dr = 0`（0=有效，1=已删除） |
| 表名 | 全大写，无数据库前缀 |
| 字段别名 | 中文 |

---

## 二、pk_corp 过滤速查

### 需要 pk_corp = '1006' 的表

**单据主表**：SO_SALE, SO_SALEINVOICE, SO_SQUARE, SO_SQUAREDETAIL, IC_GENERAL_H, TO_BILL, ARAP_DJFB

**单据附表**（跟随主表）：SO_SALEINVOICE_B, SO_SQUARE_B, IC_GENERAL_B, TO_BILL_B

**管理档案**：BD_CUMANDOC, BD_INVMANDOC, BD_PAYTERM, SO_CUCREDIT

**业务表**：IC_ONHANDNUM, IA_GENERALLEDGER

### 不需要 pk_corp 的表

**基础档案**：BD_INVBASDOC, BD_STORDOC, BD_CUBASDOC, BD_PSNDOC, BD_DEPTDOC, BD_AREACL, BD_CUSTADDR

**系统表**：BD_BILLTYPE, BD_BUSITYPE, BD_DEFDOC, SM_USER

**视图**：V_ZLW_CUST（也不需要 dr）

> **口诀**：单据表、管理档案、业务数据表 → 加 pk_corp；基础档案、系统表 → 不加。附表跟随主表规则。

---

## 三、必须遵守的编码规则

### 3.1 安全计算

```sql
-- 除零保护
CASE WHEN noutnum = 0 THEN 0 ELSE ROUND(noutmny / noutnum, 2) END

-- 金额精度
ROUND(数量 * 单价, 2) AS 金额

-- NULL处理
COALESCE(termid, '0')
IFNULL(blargessflag, 'N')

-- 日期转换
CAST(dbilldate AS DATE)
DATE_ADD(CAST(dbilldate AS DATE), INTERVAL CAST(COALESCE(termid, '0') AS INT) DAY)
```

### 3.2 销售流水统一公式

**此公式在所有视图和报表中必须保持一致**：

```sql
CASE 
    WHEN sq.blargessflag = 'Y' THEN 0
    WHEN sq.vbodydef5 IS NOT NULL AND sq.vbodydef5 != 0 THEN
        ROUND(sq.vbodydef5 / (1 + sq.ntaxrate * 0.01) * sq.noutnum, 2)
    ELSE
        ROUND(sq.noriginalcurmny / (1 + sq.ntaxrate * 0.01), 2)
END AS 销售流水
```

毛利 = 销售流水 - `sq.ncostmny`

### 3.3 成本单价公式

```sql
COALESCE(
    gl.nabprice,
    CASE WHEN gl.noutnum = 0 OR gl.noutnum IS NULL THEN 0 
         ELSE ROUND(gl.noutmny / gl.noutnum, 2) END
) AS 结存单价
```

### 3.4 常用过滤条件

```sql
AND cuman.custflag IN ('0', '2')              -- 只查客户（非供应商）
AND IFNULL(sq.blargessflag, 'N') = 'N'        -- 排除赠品
AND SUBSTR(invbas.invcode, 1, 2) != '98'  -- 排除特殊编码
AND invbas.width IN ('兼容', '原装', '打印机','电脑PC') -- 主要品类
AND oh.nonhandnum != 0                         -- 排除零库存
AND h.fbillflag >= 3                           -- 出入库已审批
AND fb.djdl = 'ys' AND fb.isverifyfinished = 'N'  -- 应收未核销

-- 单据表时间戳控制（只取近两年数据，避免全表扫描）
-- 适用表: SO_SALE, SO_SALEINVOICE, SO_SQUARE, SO_SQUAREDETAIL,
--         IC_GENERAL_H, TO_BILL, ARAP_DJFB
AND sq.ts >= DATE_FORMAT(DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR), '%Y-%m-%d')
-- 或用制单日期: AND sq.dmakedate >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR)
```

---

## 四、八大关联模式

### 模式1：销售毛利分析

```sql
FROM SO_SQUAREDETAIL sq
    INNER JOIN BD_INVMANDOC invman ON sq.cinventoryid = invman.pk_invmandoc
        AND invman.pk_corp = '1006' AND invman.dr = 0
    INNER JOIN BD_INVBASDOC invbas ON invman.pk_invbasdoc = invbas.pk_invbasdoc
        AND invbas.dr = 0
    LEFT JOIN BD_CUMANDOC cuman ON sq.ccustomerid = cuman.pk_cumandoc
        AND cuman.pk_corp = '1006' AND cuman.dr = 0
    LEFT JOIN BD_CUBASDOC cumbase ON cuman.pk_cubasdoc = cumbase.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PSNDOC psn ON sq.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON sq.cdeptid = dept.pk_deptdoc AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept ON dept.pk_fathedept = fdept.pk_deptdoc AND fdept.dr = 0
    LEFT JOIN BD_BUSITYPE btp ON sq.cbiztype = btp.pk_busitype AND btp.dr = 0
WHERE sq.pk_corp = '1006' AND sq.dr = 0
```

### 模式2：库存查询（含成本）

```sql
FROM IC_ONHANDNUM oh
    INNER JOIN BD_INVBASDOC inv ON oh.cinvbasid = inv.pk_invbasdoc AND inv.dr = 0
    INNER JOIN BD_STORDOC stor ON oh.cwarehouseid = stor.pk_stordoc AND stor.dr = 0
    LEFT JOIN BD_INVMANDOC invman ON inv.pk_invbasdoc = invman.pk_invbasdoc
        AND invman.pk_corp = '1006' AND invman.dr = 0
    LEFT JOIN IA_GENERALLEDGER gl ON invman.pk_invmandoc = gl.cinventoryid
        AND oh.ccalbodyid = gl.crdcenterid AND gl.dr = 0  -- 双字段关联！
WHERE oh.pk_corp = '1006' AND oh.dr = 0
```

### 模式3：客户完整信息（含账期+信用）

```sql
FROM BD_CUMANDOC cuman  -- 必须用CUMANDOC做主表
    INNER JOIN BD_CUBASDOC cumbase ON cumbase.pk_cubasdoc = cuman.pk_cubasdoc
        AND cumbase.dr = 0
    LEFT JOIN BD_PAYTERM term ON cuman.pk_payterm = term.pk_payterm
        AND term.pk_corp = '1006' AND term.dr = 0
    LEFT JOIN BD_PSNDOC psn ON psn.pk_psndoc = cuman.pk_resppsn1 AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON cuman.pk_respdept1 = dept.pk_deptdoc AND dept.dr = 0
    LEFT JOIN BD_DEPTDOC fdept ON dept.pk_fathedept = fdept.pk_deptdoc AND fdept.dr = 0
    LEFT JOIN SO_CUCREDIT redit ON cumbase.pk_cubasdoc = redit.pk_cubasdoc
        AND redit.climittypeid = '0001A110000000002EXU' AND redit.vcredittypename = '2' AND redit.dr = 0
    LEFT JOIN SO_CUCREDIT redits ON cumbase.pk_cubasdoc = redits.pk_cubasdoc
        AND redits.climittypeid = '0001A110000000002EXV' AND redits.vcredittypename = '2' AND redits.dr = 0
    LEFT JOIN (
        SELECT cl.pk_areacl, c.areaclname AS sf, cl.areaclname AS cs
        FROM BD_AREACL c INNER JOIN BD_AREACL cl ON c.pk_areacl = cl.pk_fatherarea
    ) dq ON cumbase.pk_areacl = dq.pk_areacl
WHERE cuman.pk_corp = '1006' AND cuman.dr = 0 AND cuman.custflag IN ('0', '2')
```

### 模式4：应收账龄

```sql
FROM ARAP_DJFB fb
    LEFT JOIN BD_PAYTERM ter ON fb.sfkxyh = ter.pk_payterm AND ter.pk_corp = '1006' AND ter.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON fb.hbbm = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN V_ZLW_CUST cu ON cub.pk_cubasdoc = cu.pk_cubasdoc
WHERE fb.pk_corp = '1006' AND fb.dr = 0 AND fb.djdl = 'ys' AND fb.isverifyfinished = 'N'
```

### 模式5：销售发票明细

```sql
FROM SO_SALEINVOICE ii
    INNER JOIN SO_SALEINVOICE_B ib ON ib.csaleid = ii.csaleid AND ib.dr = 0
    INNER JOIN BD_INVBASDOC inv ON ib.cinvbasdocid = inv.pk_invbasdoc AND inv.dr = 0
    LEFT JOIN SO_SALE od ON ib.coriginalbillcode = od.vreceiptcode
        AND od.pk_corp = '1006' AND od.dr = 0
    LEFT JOIN BD_CUMANDOC cum ON ii.creceiptcustomerid = cum.pk_cumandoc
        AND cum.pk_corp = '1006' AND cum.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON cum.pk_cubasdoc = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN BD_PSNDOC psn ON ii.cemployeeid = psn.pk_psndoc AND psn.dr = 0
WHERE ii.pk_corp = '1006' AND ii.dr = 0
```

### 模式6：出入库

```sql
FROM IC_GENERAL_H h
    INNER JOIN IC_GENERAL_B b ON h.cgeneralhid = b.cgeneralhid AND b.dr = 0
    INNER JOIN BD_INVBASDOC inv ON b.cinvbasid = inv.pk_invbasdoc AND inv.dr = 0
    INNER JOIN BD_BILLTYPE bt ON h.cbilltypecode = bt.pk_billtypecode AND bt.dr = 0
    LEFT JOIN BD_STORDOC stor ON h.cwarehouseid = stor.pk_stordoc AND stor.dr = 0
    LEFT JOIN SM_USER us ON h.coperatorid = us.cuserid
WHERE h.pk_corp = '1006' AND h.dr = 0 AND h.fbillflag >= 3
```

### 模式7：调拨单

```sql
FROM TO_BILL zb
    INNER JOIN TO_BILL_B db ON zb.cbillid = db.cbillid AND db.dr = 0
    INNER JOIN BD_STORDOC rc ON db.cinwhid = rc.pk_stordoc AND rc.dr = 0
    INNER JOIN BD_STORDOC cc ON db.coutwhid = cc.pk_stordoc AND cc.dr = 0
    INNER JOIN BD_INVBASDOC ch ON db.cinvbasid = ch.pk_invbasdoc AND ch.dr = 0
    LEFT JOIN SM_USER us ON zb.coperatorid = us.cuserid
WHERE zb.pk_corp = '1006' AND zb.dr = 0
```

### 模式8：销售结算（应收分析）

```sql
FROM SO_SQUARE ss
    INNER JOIN SO_SQUARE_B sb ON ss.csaleid = sb.csaleid AND sb.dr = 0
        AND IFNULL(sb.blargessflag, 'N') = 'N'
    LEFT JOIN BD_PAYTERM m ON ss.ctermprotocolid = m.pk_payterm
    LEFT JOIN BD_CUMANDOC cum ON ss.ccustomerid = cum.pk_cumandoc
        AND cum.pk_corp = '1006' AND cum.dr = 0
    LEFT JOIN BD_CUBASDOC cub ON cum.pk_cubasdoc = cub.pk_cubasdoc AND cub.dr = 0
    LEFT JOIN BD_PSNDOC psn ON ss.cemployeeid = psn.pk_psndoc AND psn.dr = 0
    LEFT JOIN BD_DEPTDOC dept ON ss.cdeptid = dept.pk_deptdoc AND dept.dr = 0
WHERE ss.pk_corp = '1006' AND ss.dr = 0
```

---

## 五、主表选择速查

| 业务场景 | 主表 |
|---------|------|
| 销售毛利/绩效 | SO_SQUAREDETAIL |
| 销售发票明细 | SO_SALEINVOICE_B |
| 销售订单 | SO_SALE |
| 库存查询 | IC_ONHANDNUM |
| 成本查询 | IA_GENERALLEDGER |
| 出入库 | IC_GENERAL_H |
| 调拨 | TO_BILL |
| 应收结算 | SO_SQUARE |
| 应收明细 | ARAP_DJFB |
| 客户信息 | BD_CUMANDOC（**不是**BD_CUBASDOC） |

---

## 六、业务特殊规则

| 规则 | 值/条件 |
|------|---------|
| 退货单识别 | `coriginalbillcode LIKE 'TH%'` 或 `LIKE '3U%'` |
| 商桥客户 | `cumbase.def3 = '0001C11000000012TJ3X'` |
| 散户标识 | `cumbase.freecustflag` |
| 客商属性 | '0'/'2'=客户，'1'=供应商 |
| 品类字段 | `invpinpai`=品牌，`width`=大类，`length`=品类，`height`=小类 |
| 可欠款信用 | `climittypeid = '0001A110000000002EXU'`，`vcredittypename = '2'` |
| 临时信用 | `climittypeid = '0001A110000000002EXV'`，`vcredittypename = '2'` |
| 调拨超期标准 | 南京4天、西安5天、成都10天、沈阳11天 |
| 调拨状态 | 1自由/2保存/4审批中/5已审批/7关闭 |
| 出入库审批 | `fbillflag >= 3` |

---

## 七、十大易错点

1. 忘加 `pk_corp = '1006'`（单据表和管理档案）
2. 忘加 `dr = 0`（所有表）
3. 基础档案表错加 `pk_corp`（BD_INVBASDOC等不需要）
4. 客户查询用 BD_CUBASDOC 做主表（应该用 BD_CUMANDOC）
5. 存货总账只用单字段关联（必须同时匹配 cinventoryid + ccalbodyid=crdcenterid）
6. 信用额度只关联一次 SO_CUCREDIT（需关联两次+正确的 climittypeid）
7. 除法无除零保护
8. 流水公式不统一（全局必须用同一套三级公式）
9. 地区查询直接JOIN BD_AREACL（需子查询自关联）
10. termid直接当天数（需 `CAST(COALESCE(termid,'0') AS INT)`）

---

## 八、SQL格式规范

```sql
-- 文件头注释
-- =====================================================
-- {类型}{编号}: {名称}
-- 用途: {一句话}
-- 更新频率: {频率}
-- =====================================================

SELECT
    字段1 AS 中文名1,
    字段2 AS 中文名2,
    ROUND(SUM(金额字段), 2) AS 合计金额
FROM 
    主表 别名
    INNER JOIN 必须关联表 别名2
        ON 别名.外键 = 别名2.主键
        AND 别名2.dr = 0
    LEFT JOIN 可选关联表 别名3
        ON 别名.外键 = 别名3.主键
        AND 别名3.dr = 0
WHERE 
    别名.pk_corp = '1006'
    AND 别名.dr = 0
    AND 业务条件
GROUP BY 
    字段1, 字段2
ORDER BY 
    合计金额 DESC;
```

---

**完整流程规范**: `docs/SQL开发全流程规范.md`  
**业务SQL模板**: `docs/业务场景SQL模板.md`  
**表关系详情**: `docs/数据库表关系图.md`  
**数据字典**: `docs/数据字典.md`  
**物化视图设计**: `docs/物化视图设计.md`
