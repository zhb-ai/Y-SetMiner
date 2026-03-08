--select ma.日期,ma.存货名称,ma.品类,sum(ma.销售数量),sum(ma.放货数量),sum(ma.总数量),sum(ma1.采购数量),sum(采购金额)
--from 

select 
ma.月份,ma.存货名称,ma.品类,ma.品牌,ma.小类,ma.省,
--sum(case when ma.是否放货 ='销售' then ma.数量 else 0 end ) 销售数量,
--sum(case when ma.是否放货 ='放货' then ma.数量 else 0 end ) 放货数量,
sum(ma.数量) 总数量,sum(ma.价税合计) 金额,count(distinct ma.客户名称) as 客户数,count(ma.存货名称) as 单次
 from (
select ii.csaleid,
ib.pk_invbasdoc,
 ii.VRECEIPTCODE,
    ii.dbilldate as 日期,
    substr(ii.dbilldate,1,7) as 月份,
    cu.deptname as 市场部 ,
    cu.n_deptname as 部门 ,
    cu.psnname as 业务员 ,
cu.pk_cumandoc 客户主键 ,
cu.custcode as 客户编码 ,
cu.custname as 客户名称  ,
 cu.sf as 省 ,
       cu.cs as 市 ,
       II.VDEF7 AS 货运公司 ,
    ii.dr ,
  --  (case when ib.nsummny =0 or  ib.nsummny is null then 0.1 else  ib.nsummny end)/(case when ib.nnumber =0 or  ib.nnumber is null then 0.1 else  ib.nnumber end) as 单价 ,
      yw.businame as 业务类型,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.blargessflag  as 是否赠品,
       translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
       translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1  ,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ck.storname as 库房,
       case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag,ch.pk_invbasdoc
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
  ii.dbilldate <='2020-04-16'
  and  yw.busicode <> 's005'
 -- and ck.storname in ('工厂直发库')
 and ii.dr=0 
 and ib.width  ='兼容'
 --and ib.invpinpai ='方格博士经济装'
 --and (ck.storname not like '%残%'or ck.storname not like '%虚拟%'or ck.storname not like '%维修%'  or ck.storname not in ('天猫库','中山仓','工厂直发库'))  
-- and ib.length ='硒鼓'
 --and ( cu.n_deptname like '%淘宝%' or cu.n_deptname like '%天猫%'or cu.n_deptname like '%拼多多%')--线上to C
 --and cu.custname like '%西藏%'and  cu.psnname like '%向鹏%' --向鹏大客户
  --and ib.invpinpai in ('方格博士') and   (ib.invname like '%CF41%' OR  ib.invname like '%CF50%' OR ib.invname like '%CF51%')             --and ck.storname ='1号库' 
  union all 
  select ii.csaleid ,
  ib.pk_invbasdoc,
 ii.VRECEIPTCODE,
    ii.dbilldate as 日期,
    substr(ii.dbilldate,1,7) as 月份,
    cu.deptname as 市场部,
    cu.n_deptname as 部门,
    cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
 cu.sf as 省 ,
       cu.cs as 市 ,
       II.VDEF7 AS 货运公司,
    ii.dr ,
  --  (case when ib.nsummny =0 or  ib.nsummny is null then 0.1 else  ib.nsummny end)/(case when ib.nnumber =0 or  ib.nnumber is null then 0.1 else  ib.nnumber end) as 单价 ,
      yw.businame as 业务类型,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.blargessflag  as 是否赠品,
       translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
       translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1  ,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ck.storname as 库房,
       case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc
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
 where 
  ii.dbilldate >'2020-04-17'
 and ii.dr=0 
and ib.width  ='兼容'
 )ma  where  ma.日期 between '2020-10-01' and  '2020-12-31'and ma.库房 = '工厂直发库'
  group by ma.月份,ma.存货名称,ma.品类,ma.品牌,ma.小类,ma.省


 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 )
 ma left join 
 (
 select  ma1.日期1,ma1.供应商名称 ,ma1.品类,sum(ma1.数量)as 采购数量,sum(ma1.价税合计)as 采购金额 from 
(select/*采购发票金额*/
aa.dinvoicedate as 日期1,
yy.custname as 供应商名称,
cc.invcode as 存货编码,
cc.invname as 存货名称1,
cc.length as 品类,
bb.ninvoicenum as 数量,
bb.nsummny as 价税合计
--bb.nsummny/bb.ninvoicenum as 单价,
--cc.length as 品类,
--cc.invpinpai as 品牌,
--cc.width as 大类
from nc5x.po_invoice_b bb
join nc5x.po_invoice aa
  on bb.cinvoiceid = aa.cinvoiceid
join nc5x.bd_invbasdoc cc
  on bb.cbaseid = cc.pk_invbasdoc
join (select xx.custname,aa.cvendorbaseid,aa.cinvoiceid
        from nc5x.po_invoice aa
        join nc5x.bd_cubasdoc xx
          on aa.cvendorbaseid =xx.pk_cubasdoc)yy
  on yy.cinvoiceid = aa.cinvoiceid and aa.dr = 0
where aa.dinvoicedate >='2020-01-16'
and aa.dinvoicedate <='2020-11-16'
and cc.width='兼容'
and bb.ninvoicenum > 0
) ma1 group by  ma1.日期1,ma1.供应商名称,ma1.品类
 ) ma1 
on ma.存货名称=ma1.存货名称1 and  ma.日期=ma1.日期1
 group by ma.日期,ma.存货名称,ma.品类




