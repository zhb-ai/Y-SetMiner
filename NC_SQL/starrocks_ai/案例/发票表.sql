select 客户主键 ,业务员,部门,客户名称,大类 ,存货名称,品类,品牌, sum(数量),count(distinct 日期) 日期数 ,max(日期) 最后交易日期 from (
select 
ib.ccustomerid,
m.vreceiptcode 外部单号,
ib.coriginalbillcode 订单号,
us.user_name 操作人,
ii.csaleid as 主键,
ib.pk_invbasdoc 存货主键,
ii.creceiptcustomerid,
ii.daudittime 审核时间,
ii.VRECEIPTCODE 发票号,
ii.dbilldate as 日期,
substr(ii.dbilldate,1,7) as 月份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称,
m.daudittime ,
cu.sf as 省 ,
cu.cs as 市 ,
II.VDEF7 AS 货运公司,
ii.dr 删除标志 ,
yw.businame as 业务类型,
ii.vnote as 备注,
ib.nnumber as 数量,
ib.nsummny as 价税合计,
 ib.noriginalcurmny as 流水,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.blargessflag  as 是否赠品,
translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号 ,
translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
ck.storname as 库房,
m.vdef20 as 收货地址,
ii.vdef8 ,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
from nc5x.so_saleinvoice ii
join (select  ib.noriginalcurmny, ib.ccustomerid,ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
  on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ib.ccustomerid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.sm_user us
on m.coperatorid = us.cuserid 
where 
ii.dr=0 
and ib.width  = '兼容'
and ii.dbilldate >= '2021-01-01'-- and '2022-01-07' 
-- and  yw.busicode = 's005'
) group by  客户主键,业务员,部门 ,客户名称,大类 ,存货名称 ,品类,品牌
