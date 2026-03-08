select sb.corder_bid as 主键,
sb.ts as 时间戳,
sh.vreceiptcode as 订单号,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
sh.ccustomerid as 客户主键,
sh.dbilldate  as 日期,
sh.vnote as 备注,
sb.cinvbasdocid as 存货主键,
sb.nnumber as 数量,
ck.storname as 出货仓库,
sh.dr as 删除标志,
-- yw.busicode ,
sb.frowstatus as 行标志    
from nc5x.so_sale sh
left join nc5x.so_saleorder_b sb on sh.csaleid =sb.csaleid 
LEFT join nc5x.v_zlw_cust cu
on sh.ccustomerid  = cu.pk_cumandoc
LEFT join nc5x.bd_stordoc ck
on sh.cwarehouseid = ck.pk_stordoc
left join nc5x.bd_busitype yw
on sh.cbiztype = yw.pk_busitype
where 
sb.ts >=to_char(sysdate-1,'yyyy-MM-dd') || ' 00:00:00' 
-- and sb.ts <=to_char(sysdate-1,'yyyy-MM-dd') || ' 00:00:00'    
--and yw.busicode <> 's005'
and cu.deptname ='区域销售部'

