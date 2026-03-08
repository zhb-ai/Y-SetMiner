/*商桥下单*/
select distinct
cu.pk_cubasdoc as 客户主键,
cu.custname as 客户名称,
cu.custcode as 客户编码,
cu.deptname as 市场部,
cu.psnname as 业务员,
sx.dbilldate as 日期,
sx.dbilltime as 下单时间,
ck.storname as 库房,
sx.vreceiptcode as 订单号,
sx.VDEF16 as 备注
from nc5x.so_sale sx
join nc5x.v_zlw_cust cu
on sx.ccustomerid = cu.pk_cumandoc
join nc5x.bd_stordoc ck
on sx.cwarehouseid = ck.pk_stordoc
where sx.dbilldate >= '2021-03-01'
and sx.dbilldate <= '2021-03-31'
and sx.VDEF16 like  '%SQ%'
and cu.deptname <>  '直营+微分销'
order by sx.dbilldate asc ,cu.custname asc
