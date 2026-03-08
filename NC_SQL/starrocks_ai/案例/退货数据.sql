select  客户名称,客户编码,sum(退货流水)退货流水,sum(流水)流水,count(distinct 退货订单号) as 退货订单数,count(distinct 订单号) as 订单数 from (
select 
case when  (ib.CORIGINALBILLCODE  like 'TH%' or ib.CORIGINALBILLCODE  like '3U%') then ib.CORIGINALBILLCODE else '0' end 退货订单号,
  case when  (ib.CORIGINALBILLCODE  like 'TH%' or ib.CORIGINALBILLCODE  like '3U%') then ib.noriginalcurmny else 0 end 退货流水,
ib.CORIGINALBILLCODE 订单号,
w.user_name as 制单人 ,
substr(ii.dbilldate,1,7) as 月份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
cu.pk_cubasdoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
ib.nnumber as 数量,
ib.nsummny as 价税合计,
ib.noriginalcurmny as 流水,
ib.invcode as 存货编码,
ib.invname as 存货名称,
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
m.vdef20 as 收货地址,
m.vdef8 as 服务商,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
 left  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny,
  ch.unitvolume ,
ch.unitweight 
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc
             ) ib
    on ib.csaleid = ii.csaleid
  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcustomerid = cu.pk_cumandoc
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
and  ii.dr = 0 
and (ii.dbilldate between '2021-01-01' and  '2022-08-31')


) 
group by  客户名称,客户编码 
