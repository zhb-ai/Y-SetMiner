--select ma.日期,ma.存货名称,ma.品类,sum(ma.销售数量),sum(ma.放货数量),sum(ma.总数量),sum(ma1.采购数量),sum(采购金额)
--from 
--select  ma.地址,ma.库房,count(distinct 单号),count(distinct ma.客户名称),sum(ma.价税合计)
select  ma.客户名称,sum(方格博士数量) ,sum(方格博士经济装数量)
,sum(扬帆耐立数量)
,sum(盈佳数量)
,sum(懿智通实惠装数量)
,sum(懿品数量)
,sum(智通数量)
,sum(懿智通数量)
,sum(懿品佳数量) from (
select ma.客户名称,ma.存货名称,ma.存货编码,
case when  ma.品牌 ='方格博士' then ma.数量 else 0 end 方格博士数量,
case when  ma.品牌 ='方格博士经济装' then ma.数量 else 0 end 方格博士经济装数量,
case when  ma.品牌 ='扬帆耐立' then ma.数量 else 0 end 扬帆耐立数量,
case when  ma.品牌 ='盈佳' then ma.数量 else 0 end 盈佳数量,
case when  ma.品牌 ='懿智通实惠装' then ma.数量 else 0 end 懿智通实惠装数量,
case when  ma.品牌 ='懿品' then ma.数量 else 0 end 懿品数量,
case when  ma.品牌 ='智通' then ma.数量 else 0 end 智通数量,
case when  ma.品牌 ='懿智通' then ma.数量 else 0 end 懿智通数量,
case when  ma.品牌 ='懿品佳' then ma.数量 else 0 end 懿品佳数量,
ma.数量 as 总数量
from (
select ii.csaleid,
ib.pk_invbasdoc,
 ii.VRECEIPTCODE as 单号,
    ii.dbilldate as 日期,
    substr(ii.dbilldate,1,7) as 月份,
    cu.deptname as 市场部 ,
    cu.n_deptname as 部门 ,
    cu.psnname as 业务员 ,
cu.pk_cumandoc 客户主键 ,
cu.custcode as 客户编码 ,
cu.custname as 客户名称 ,
 cu.sf as 省 ,
       cu.cs as 市 ,
       II.VDEF7 AS 货运公司 ,
    ii.dr ,
    m.vdef20 as 地址,
      yw.businame as 业务类型,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.blargessflag  as 是否赠品,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ck.storname as 库房,
       case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
  join (select  ib.coriginalbillcode,ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag,ch.pk_invbasdoc
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
     left join  nc5x.so_sale m 
 on ib.coriginalbillcode =m.vreceiptcode
  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcustomerid = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
 where 
  ii.dbilldate <= '2020-04-16'
  and  yw.busicode <> 's005'
 -- and ck.storname in ('工厂直发库')
 and ii.dr=0 

-- and ib.width  ='兼容'
 --and ib.invpinpai ='方格博士经济装'
 --and (ck.storname not like '%残%'or ck.storname not like '%虚拟%'or ck.storname not like '%维修%'  or ck.storname not in ('天猫库','中山仓','工厂直发库'))  
-- and ib.length ='硒鼓'
 --and ( cu.n_deptname like '%淘宝%' or cu.n_deptname like '%天猫%'or cu.n_deptname like '%拼多多%')--线上to C
 --and cu.custname like '%西藏%'and  cu.psnname like '%向鹏%' --向鹏大客户
  --and ib.invpinpai in ('方格博士') and   (ib.invname like '%CF41%' OR  ib.invname like '%CF50%' OR ib.invname like '%CF51%')             --and ck.storname ='1号库' 
  union all 
  select ii.csaleid,
ib.pk_invbasdoc,
 ii.VRECEIPTCODE as 单号,
    ii.dbilldate as 日期,
    substr(ii.dbilldate,1,7) as 月份,
    cu.deptname as 市场部 ,
    cu.n_deptname as 部门 ,
    cu.psnname as 业务员 ,
cu.pk_cumandoc 客户主键 ,
cu.custcode as 客户编码 ,
cu.custname as 客户名称 ,
 cu.sf as 省 ,
       cu.cs as 市 ,
       II.VDEF7 AS 货运公司 ,
    ii.dr ,
    m.vdef20 as 地址,
  --  (case when ib.nsummny =0 or  ib.nsummny is null then 0.1 else  ib.nsummny end)/(case when ib.nnumber =0 or  ib.nnumber is null then 0.1 else  ib.nnumber end) as 单价 ,
      yw.businame as 业务类型,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.blargessflag  as 是否赠品,
      -- translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
     --  translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1  ,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ck.storname as 库房,
       case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
  join (select  ib.coriginalbillcode,ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
    left  join  nc5x.so_sale m 
 on ib.coriginalbillcode =m.vreceiptcode

  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcustomerid = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
 where 
  ii.dbilldate >'2020-04-17'
  and ii.dr=0 
 -- and   (ib.invname  like '%CF40%' or  ib.invname  like '%CF50%'or  ib.invname  like '%CF51%'or  ib.invname  like '%CF41%')
   )ma 
  where (1=1) 
  AND ma.日期 between  '2021-01-01' and '2021-07-31'
  and ma.大类 in ('兼容') )ma
  group by ma.客户名称
  --AND MA.库房='京东'
 -- and ma.地址 like '%赛格%' and ma.地址 like '%电脑%'and ma.地址 like '%3%'



  

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 

