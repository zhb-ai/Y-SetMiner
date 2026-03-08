select  d.客户名称,d.存货编码,d.存货名称 ,sum( d.数量),sum(d.毛利),dense_rank()OVER(PARTITION BY d.客户名称
        ORDER BY  sum(d.毛利) desc ) AS 排名  from (select 
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
yw.businame as 业务类型,
js.vdef11 as 业务属性,
js.nsummny  as 本币价税合计,
js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) AS 流水,
ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)-js.ncostmny AS 毛利,
js.ncostmny as 成本,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
cu.custcode as 客户编码,
cu.custname as 客户名称,
to_date(js.dmakedate,'yyyy-MM-dd') as 财务日期,
cu.sf as 省,
cu.cs as 市 ,
xs.vreceiptcode 单号,
ck.storname  仓库名称
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ib.csaleid
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc
       left join  nc5x.so_saleinvoice_b ib
       on ib.cinvbasdocid = ch.pk_invbasdoc 
        )cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.so_sale  xs on   js.csaleid= xs.csaleid 
left join nc5x.so_saleinvoice ii   on cg.csaleid = ii.csaleid
  join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
where js.dmakedate >= '2019-01-23'
  and js.dmakedate <= '2020-04-23'
  and cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and cg.width='兼容'and cg.length like '%复印%'
  and js.dr=0
  --and yw.busicode <> 's005'
  and '流水' is not null)   d group by d.客户名称,d.存货编码,d.存货名称
