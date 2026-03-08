select 
存货名称,大类,品牌,品类,小类,月份,sum(流水),sum(数量) ,count(distinct 客户主键) 客户数,count(distinct 订单号 ) 订单量
from (
select 
m.daudittime 订单审批时间,
ii.daudittime 审批时间,
ii.vdef5 所属公司,
m.PK_DEFDOC6 as 收货人,m.PK_DEFDOC17 收货电话,
m.coperatorid,
ii.vreceiptcode,
ii.fstatus  审批状态,
ii.creceiptcustomerid as 主键,
ib.pk_invbasdoc 存货主键,
ii.VDEF9 运单号,
ib.CORIGINALBILLCODE 订单号,
m.vreceiptcode  as 外部单号,
ii.VRECEIPTCODE 发票号,
ii.dbilldate as 日期,
w.user_name as 制单人 ,
substr(ii.dbilldate,1,7) as 月份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
cu.pk_cubasdoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称, 
cu.sf as 省,
cu.cs as 市,
II.VDEF7 AS 货运公司,
ii.dr 删除标志,
yw.businame as 业务类型,
ii.vnote as 备注,
ib.nnumber as 数量,
ib.nsummny as 价税合计,
ib.noriginalcurmny as 流水,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.def2 as 装箱数,
ib.unitvolume*ib.nnumber as 体积,
ib.unitweight*ib.nnumber  as  重量,
ib.blargessflag  as 是否赠品,
translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1 ,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
dd.storname as 库房,
m.VDEF17 as 是否代发,
m.vdef20 as 收货地址,
m.vdef8 as 服务商,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货,
case when  yw.busicode = 's005' then ib.nsummny else 0 end 放货流水
from nc5x.so_saleinvoice ii
left  join (
select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny,ch.def2 ,
ch.unitvolume ,
ch.unitweight 
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
) ib
on ib.csaleid = ii.csaleid 
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid  = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc dd
on ii.cwarehouseid = dd.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.sm_user w
on m.coperatorid =w.cuserid
left join nc5x.bd_psndoc  us
on us.pk_psndoc= ii.cemployeeid
where (1=1) 
and length(ib.invcode) > 4 
and ii.dr = 0 
and ii.dbilldate >= '2023-01-01'
and ib.width = '原装'
and ib.invpinpai like '%佳能%'
) 
group by 存货名称,大类,品牌,品类,小类,月份
-- and ib.invname  = '惠普W1108A(108A)黑鼓'

