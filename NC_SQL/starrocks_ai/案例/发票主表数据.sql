
select 
distinct 
ib.vreceiptcode  as 订单号,
ii.VRECEIPTCODE 发票号,
ii.dbilldate 日期,
ck.storname as 库房,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
cu.custname as 开票单位,
bd.docname as 发票销方,
cu.n_deptname as 部门,
cu.psnname as 业务员,
ii.vdef9  as 运单号,
ii.vdef7  as 货运公司,
ii.ntotalsummny,
ib.nnumber 数量,
yw.businame as 业务类型,
ii.vdef11 as 业务属性,
ii.vnote as 备注,
ii.fstatus,
ii.dapprovedate ,
su1.user_name as 制单人
from nc5x.so_saleinvoice ii 
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid = cu.pk_cumandoc
left join nc5x.bd_defdoc bd 
on ii.PK_DEFDOC5 = bd.PK_DEFDOC 
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.sm_user  su1 
on ii.coperatorid = su1.cuserid
left join (select distinct ib.csaleid, s.vdef4 , s.vreceiptcode ,s.vnote,s.vdef20,ib.coriginalbillcode,nnumber
from nc5x.so_saleinvoice_b ib
join nc5x.so_sale s
on ib.coriginalbillcode = s.vreceiptcode and ib.dr = 0 ) ib
on ib.csaleid = ii.csaleid
and ii.dr = 0 
where 
ii.dr=0 
and ii.dbilldate >= '2017-01-01'
-- and ii.ntotalsummny <0 
and cu.custname  = '京东-智通仁和办公专营店'
-- and ib.nnumber < 0 
-- and ib.vreceiptcode like '%so%'

