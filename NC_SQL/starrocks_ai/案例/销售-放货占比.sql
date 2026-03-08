select sum(count(distinct ma.客户名称)),sum(case when count(ma.客户名称) = 2 then 1 else 0 end ) from (
select ma.存货名称,ma.月份,sum(ma.数量) 销量
 from (
select ii.csaleid ,
    ii.dbilldate as 日期,
    substr(ii.dbilldate,1,7) as 月份,
    cu.deptname as 市场部,
    cu.n_deptname as 部门,
    cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称,
 cu.sf as 省,
       cu.cs as 市,
    ii.dr,
  --  (case when ib.nsummny =0 or  ib.nsummny is null then 0.1 else  ib.nsummny end)/(case when ib.nnumber =0 or  ib.nnumber is null then 0.1 else  ib.nnumber end) as 单价 ,
      yw.businame as 业务类型,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ck.storname as 库房,
       case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcustomerid = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
 where --((ii.dbilldate between  '2019-01-01'and '2019-01-31')  or
 
  ii.dbilldate between  '2020-12-01'and '2020-12-31'
   --and yw.busicode <> 's005' 
 and ib.width='兼容'
 and ii.dr=0

 --and  ib.length ='硒鼓'and ck.storname ='1号库'
 --and yw.busicode <> 's005'
 )ma 
  --and cu.custname like  '%保明达%'
  group by ma.存货名称,ma.月份 )  ma   --,ma.省
 
