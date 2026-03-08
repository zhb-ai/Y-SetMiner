## 销售明细查询
select
    ib.csaleid '销售单主键',
    ib.nnumber '数量',
    (case when ib.blargessflag = 'N' then ib.nsummny else 0 end) '金额小计' ,
    ch.invpinpai '品牌',
    ch.width '大类',
    ch.length '小类',
    ch.invname '商品名称',
    ch.invcode '商品编码',
    ib.coriginalbillcode '订单号',
    cub.pk_cubasdoc  '客户主键',
    cub.custcode '客户编码',
    cub.custname '客户名称',
    psn.PSNNAME '业务员姓名',
    dept.deptname '部门名称',
    fdept.deptname '大部门',
    od.dbilldate '单据日期',
    YEAR(od.dbilldate) AS year,
    MONTH(od.dbilldate) AS month
from SO_SALEINVOICE_B ib
inner join BD_INVBASDOC ch on ib.cinvbasdocid = ch.pk_invbasdoc
inner join SO_SALEINVOICE ii on  ib.csaleid = ii.csaleid
inner join SO_SALE od on ib.coriginalbillcode =od.vreceiptcode
left join BD_PSNDOC psn on psn.pk_psndoc =od.cemployeeid
left join BD_CUMANDOC cu on od.creceiptcorpid = cu.pk_cumandoc
left join BD_CUBASDOC cub on cu.pk_cubasdoc=cub.pk_cubasdoc
left join BD_DEPTDOC dept on od.cdeptid=dept.pk_deptdoc
left join BD_DEPTDOC fdept on dept.pk_fathedept =fdept.pk_deptdoc
where ch.dr=0 and od.dr=0;


## 销售毛利分析
select 
       sq.dmakedate as 日期,
       dept.deptname as 部门,
       psn.psnname as 业务员,
       cubas.custname as 客户名称,
       btp.businame as 业务类型,
       invbas.invname as 存货名称,
       invbas.invpinpai as 品牌,
       invbas.length as 品类,
       invbas.height as 小类,
       invbas.width as 大类,
       sq.blargessflag as 是否赠品,
       sum(sq.noutnum) as 数量,
       sum(case
                     when blargessflag <> 'Y' and ifnull(sq.vbodydef5,0) = 0 then
                      sq.noriginalcurmny
                    when blargessflag <> 'Y' and ifnull(sq.vbodydef5,0) <> 0 then
                    round((ifnull(sq.vbodydef5,0)/(1+ntaxrate*1.01)) * sq.noutnum, 2)
                     else
                      0
                   end) as 流水,
       sum(sq.ncostmny) as 成本,
       sum(case
                     when blargessflag <> 'Y' and ifnull(sq.vbodydef5,0) = 0 then
                      sq.noriginalcurmny
                    when blargessflag <> 'Y' and ifnull(sq.vbodydef5,0) <> 0 then
                    round((ifnull(sq.vbodydef5,0)/(1+ntaxrate*1.01)) * sq.noutnum, 2)
                     else
                      0
                   end) - sum(sq.ncostmny) as 毛利
from SO_SQUAREDETAIL sq
   join BD_INVMANDOC invman on sq.cinventoryid = invman.pk_invmandoc
   join BD_INVBASDOC invbas on invman.pk_invbasdoc = invbas.pk_invbasdoc
                           and (invbas.invcode = '9808' 
                                or invbas.invcode = '9809' 
                                or invbas.invcode = '9813'    
                                or substr(invbas.invcode, 1, 2) <> '98')
   join BD_DEPTDOC dept on sq.cdeptid = dept.pk_deptdoc
   join BD_PSNDOC psn on sq.cemployeeid = psn.pk_psndoc
   join BD_CUMANDOC cuman on sq.ccustomerid = cuman.pk_cumandoc
   join BD_CUBASDOC  cubas on cuman.pk_cubasdoc = cubas.pk_cubasdoc
   join BD_BUSITYPE btp on sq.cbiztype = btp.pk_busitype
where sq.dr = 0
   and sq.pk_corp = '1006'
   and invman.pk_corp = '1006'
   and dept.pk_corp = '1006'
   and btp.businame <> '放货销售'
group by sq.dmakedate,
       dept.deptname, 
       psn.psnname, 
       cubas.custname,
       btp.businame,
       invbas.invname,
       invbas.invpinpai,   
       sq.blargessflag,
       invbas.length,
       invbas.height,
       invbas.width;

## 应收账龄查询
SELECT
    dept.deptname '部门名称',
    fdept.deptname '大部门',
    psn.PSNNAME '业务员姓名',
    cub.PK_CUBASDOC '客户主键',
    cub.custcode AS 客户编码,
    cub.custname AS 客户,
    (CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END) AS 单据账期,
    ss.dbilldate AS 单据日期,
    (CASE WHEN so.vreceiptcode IS NULL THEN sy.vreceiptcode ELSE so.vreceiptcode END) AS 单号,
    ss.vdef11 AS 属性,
    ss.vdef5 AS 销方公司,
    -- 超期天数 = 当前日期 - (单据日期 + 账期天数)
       DATEDIFF(CURRENT_DATE(),
                DATE_ADD(CAST(ss.dbilldate AS DATE),
                        INTERVAL CAST(CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END AS INT) DAY)) AS 超期天数,
       -- 预计结算日期 = 单据日期 + 账期天数
       DATE_ADD(CAST(ss.dbilldate AS DATE),
               INTERVAL CAST(CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END AS INT) DAY) AS 预计结算日期,
    SUM(sb.nsummny) AS 金额
FROM SO_SQUARE ss
JOIN SO_SQUARE_B sb ON ss.csaleid = sb.csaleid AND sb.dr = 0 AND IFNULL(sb.noutnum, 0) <> IFNULL(sb.nbalancenum, 0) AND IFNULL(sb.blargessflag, 'N') = 'N'
LEFT JOIN SO_SALE so ON sb.csourcebillid = so.csaleid
LEFT JOIN SO_APPLY sy ON sb.csourcebillid = sy.pk_apply
LEFT JOIN BD_PAYTERM m ON ss.ctermprotocolid = m.pk_payterm
LEFT JOIN BD_CUMANDOC cum ON ss.ccustomerid = cum.pk_cumandoc
left join BD_CUBASDOC cub on cum.pk_cubasdoc=cub.pk_cubasdoc
LEFT JOIN BD_PSNDOC psn on psn.pk_psndoc =ss.cemployeeid
LEFT JOIN BD_DEPTDOC dept on ss.cdeptid=dept.pk_deptdoc
LEFT JOIN BD_DEPTDOC fdept on dept.pk_fathedept =fdept.pk_deptdoc
WHERE ss.dr = 0 AND ss.cbiztype = '1006A1100000000000Z4'AND DATE_ADD(CAST(ss.dbilldate AS DATE),INTERVAL CAST(CASE WHEN m.termid = '01' OR m.termid IS NULL THEN '0' ELSE m.termid END AS INT) DAY) <= CURRENT_DATE() + INTERVAL 10 DAY
GROUP BY dept.deptname,
          fdept.deptname,
          psn.PSNNAME,
          cub.PK_CUBASDOC,
          cub.custcode,
          cub.custname,
          m.termid,
          ss.dbilldate,
          so.vreceiptcode,
          sy.vreceiptcode,
          ss.vdef11,
          ss.vdef5
 order by dept.deptname,
          cub.custname,
          ss.dbilldate,
          so.vreceiptcode,
          sy.vreceiptcode



## 仓库存货成本
SELECT
    dd.storname AS 库房,
    bb.invcode AS 存货编码,
    bb.invname AS 存货名称,
    bb.width AS 大类,
    bb.invpinpai AS 品牌,
    bb.length AS 品类,
    bb.height AS 小类,
    dd.nonhandnum AS 结存数量,
    COALESCE(
        gg.nabprice,
        CASE WHEN gg.noutnum = 0 THEN 0 ELSE ROUND(gg.noutmny / gg.noutnum, 2) END
    ) AS 金额,
    dd.nonhandnum * COALESCE(
        gg.nabprice,
        CASE WHEN gg.noutnum = 0 THEN 0 ELSE ROUND(gg.noutmny / gg.noutnum, 2) END
    ) AS 库存金额
FROM BD_INVBASDOC bb
INNER JOIN (
    SELECT
        aa.cinvbasid,
        aa.cwarehouseid,
        aa.nonhandnum,
        cc.storname
    FROM IC_ONHANDNUM aa
    INNER JOIN BD_STORDOC cc ON aa.cwarehouseid = cc.pk_stordoc
    WHERE aa.nonhandnum <> 0
) dd ON dd.cinvbasid = bb.pk_invbasdoc
INNER JOIN (
    SELECT
        ee.pk_invbasdoc,
        ff.nabprice,
        ff.noutmny,
        ff.noutnum
    FROM BD_INVMANDOC ee
    INNER JOIN IA_GENERALLEDGER ff ON ee.pk_invmandoc = ff.cinventoryid
    WHERE ff.dr = 0
      AND ff.caccountmonth <> '00'
      AND ff.noutnum IS NOT NULL  -- 避免除零错误
) gg ON gg.pk_invbasdoc = bb.pk_invbasdoc
WHERE SUBSTR(bb.invcode, 1, 2) <> '98'
  AND dd.nonhandnum IS NOT NULL;


## 客商信息关联信用额度，账期（收款协议）
select
    cumbase.pk_cubasdoc as '客户主键',
    cuman.pk_cumandoc AS 客户管理主键,
    cumbase.custcode as '客户编码',
    cumbase.custname as '客户名称',
    cumbase.createtime '创建日期',
    cumbase.freecustflag as '是否散户',
    cumbase.isconnflag as '是否渠道成员',
    cumbase.linkman1 as '联系人1',
    cumbase.linkman2 as '联系人2',
    cumbase.linkman3 as '联系人3',
    cumbase.mobilephone1 as '联系人电话1',
    cumbase.mobilephone2 as '联系人电话2',
    cumbase.mobilephone3 as '联系人电话3',
    cumbase.phone1 as '联系人座机1',
    cumbase.phone2 as '联系人座机2',
    cumbase.phone3 as '联系人座机3',
    cumbase.BP1 as 'QQ微信',
    cumbase.BP2 as '呼机2',
    cumbase.BP3 as '客户来源',
    cumbase.CONADDR '地址',
    cumbase.MNECODE '助记码',
    cuman.sealflag as '封存标记',
    cuman.custflag as '客商属性',
    cuman.custstate as '客商状态',
    cuman.innerctldays as '信用天数',
    term.TERMNAME as '付款协议',
    redit.nlimitmny AS 信用额度,
    redits.nlimitmny AS 临时信用额度,
    cuman.memo as '备注',
    cuman.pk_resppsn1 as '业务员主键',
    psn.psnname as '业务员姓名',
    dept.deptname '部门名称',
    fdept.deptname '大部门',
    (case when cumbase.def3 = '0001C11000000012TJ3X' then 'Y' else  'N' end) 商桥,
    dq.sf '省',
    dq.cs '市',
    cumbase.def10 AS 开票信息,
    CASE WHEN cuman.sealflag IS NOT NULL OR LENGTH(LTRIM(RTRIM(cuman.sealflag))) > 0 THEN 'Y' ELSE 'N' END AS 是否封存
from BD_CUMANDOC as cuman inner join BD_CUBASDOC as cumbase on cumbase.PK_CUBASDOC=cuman.PK_CUBASDOC
left join BD_PAYTERM as term on cuman.pk_payterm=term.pk_payterm
left join BD_PSNDOC psn on psn.pk_psndoc  =cuman.pk_resppsn1
left join BD_DEPTDOC dept on cuman.pk_respdept1=dept.pk_deptdoc
left join BD_DEPTDOC fdept on dept.pk_fathedept =fdept.pk_deptdoc
left  join(select cl.pk_areacl,c.areaclname sf,cl.areaclname cs from BD_AREACL c join BD_AREACL cl on c.pk_areacl = cl.pk_fatherarea ) dq on cumbase.pk_areacl = dq.pk_areacl
left join SO_CUCREDIT redit on cumbase.pk_cubasdoc = redit.pk_cubasdoc and redit.climittypeid = '0001A110000000002EXU' and redit.vcredittypename = '2' and redit.dr =0
left join SO_CUCREDIT redits on cumbase.pk_cubasdoc = redits.pk_cubasdoc and redits.climittypeid = '0001A110000000002EXV' and redits.vcredittypename = '2' and redits.dr = 0
where cumbase.DR=0 and cuman.DR=0 and cuman.CUSTFLAG in ('0', '2') and cuman.pk_corp = '1006'