select
部门  ,业务员  ,客户编码,  客户名称,	大类	,品牌
,sum(价税合计) 价税合计 ,sum(数量) 数量,count(distinct vreceiptcode ) 订单量,count(distinct 商桥订单 ) 商桥订单量,count(distinct 日期 ) 频次
from (
select
ii.fstatus,
ii.vdef20 ,
ii.csaleid as 主键,
bd.docname as 发票销方,
bdd.docname as 订单销方,
m.creceiptcorpid,
nvl(m.vreceiptcode,th.vsourcecode ) as vreceiptcode,
case when  m.VDEF16 = 'SQ' then m.vreceiptcode  else null end 商桥订单,
cuu.custname as 开票单位,
ib.pk_invbasdoc 存货主键,
ii.VRECEIPTCODE 发票号,
ii.dbilldate as 日期,
substr(ii.dbilldate,1,7) as 月份,
substr(ii.dbilldate,1,4) as 年份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
cu.sf as 省 ,
cu.cs as 市 ,
II.VDEF7 AS 货运公司,
ii.dr 删除标志 ,
yw.businame as 业务类型,
ii.vnote as 备注,
ib.nnumber as 数量,
ib.nsummny as 价税合计,
ib.noriginalcurmny  as 流水,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.blargessflag as 是否赠品,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
ck.storname as 库房,
m.vdef20 as 收货地址,
m.pk_defdoc16 销售省份,
m.pk_defdoc20 销售城市,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
from nc5x.so_saleinvoice ii
join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ib.noriginalcurmny,
ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag
,ch.pk_invbasdoc,ib.coriginalbillcode,csourcebillid,th.vreceiptcode
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
left join nc5x.so_apply th
on ib.csourcebillid = th.pk_apply
) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu
on ii.creceiptcorpid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
left  join  nc5x.so_sale m
on ib.coriginalbillcode = m.vreceiptcode
left join nc5x.v_zlw_cust cuu
on m.creceiptcorpid = cuu.pk_cumandoc
left join nc5x.bd_defdoc bd
on ii.PK_DEFDOC5 = bd.PK_DEFDOC
left join nc5x.bd_defdoc bdd
on m.PK_DEFDOC5 = bdd.PK_DEFDOC
left join nc5x.so_apply th
on ib.csourcebillid = th.pk_apply

where
length(invcode) > 5
and ii.dr = 0
and nvl(m.vreceiptcode,ib.vreceiptcode) is not null

and  ii.dbilldate >= '2025-08-01' 
-- and  ii.dbilldate between  '2025-07-01' and '2025-07-31'
-- and ib.invname like '%定制%'
-- and yw.businame like '%电商%'
-- and cu.deptname <> '直营+微分销'
-- and ib.invpinpai like '%网络版%'
-- and ib.width  = '兼容'
-- and cu.custname in ('天津新星启科技有限公司')

) group by 部门	,业务员	,客户编码,	客户名称,	大类	,品牌



