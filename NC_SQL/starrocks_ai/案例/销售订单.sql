select --sb.corder_bid as 主键,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.custname,
sh.daudittime as 审批时间,
substr(sh.daudittime,12,8) 时间,
sh.dbilltime as 单据时间,
sh.dmoditime as 最后修改时间,
--c.dbilldate  as 日期,
sh.vreceiptcode as 订单号,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
sh.ccustomerid as 客户主键,
--sh.vnote as 备注,
--sb.cinvbasdocid as 存货主键,
sb.nnumber as 数量,
ck.storname as 出货仓库 
from nc5x.so_sale sh
left join nc5x.so_saleorder_b sb on sh.csaleid =sb.csaleid 
LEFT join nc5x.v_zlw_cust cu
on sh.ccustomerid  = cu.pk_cumandoc
LEFT join nc5x.bd_stordoc ck
on sh.cwarehouseid = ck.pk_stordoc
left join nc5x.bd_busitype yw
on sh.cbiztype = yw.pk_busitype
left join (select distinct ib.coriginalbillcode,ii.dbilldate from 
(select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.coriginalbillcode
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
join nc5x.so_saleinvoice ii    on ib.csaleid = ii.csaleid)c  on sh.vreceiptcode=c.coriginalbillcode
where ck.storname <>'首创虚拟库'
and sh.dapprovedate  =  '2024-10-23'
and sh.dr = 0

--to_char('2020-08-01','yyyy-MM-dd') || ' 00:00:00' 
-- and sb.ts     
--and yw.busicode <> 's005'






