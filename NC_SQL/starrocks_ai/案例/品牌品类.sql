select 
ma.存货名称 ,
--ma.品类 ,
case when ma.品类 = '硒鼓' and ma.小类='黑色' then '黑色硒鼓'
     when ma.品类 = '硒鼓' and ma.小类='彩色' then '彩色硒鼓' 
     else ma.品类 end 品类,
ma.品牌,ma.月份,ma.是否放货,sum(case when ma.是否放货 ='销售' then ma.数量 else 0 end ) 销售数量,
sum(case when ma.是否放货 ='放货' then ma.数量 else 0 end ) 放货数量,sum(ma.数量) 总数量,sum(ma.价税合计) 金额,count(distinct ma.客户名称  ) as 客户数,count(ma.存货名称) as 单次
 from (
select ii.csaleid ,
    ii.dbilldate as 日期,
    substr(to_char(to_date(ii.dbilldate,'yyyy-mm-dd'),'yyyy-mm-dd'),1,7) as 月份,
    cu.deptname as 市场部,
    cu.n_deptname as 部门,
    cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
 cu.sf as 省 ,
       cu.cs as 市 ,
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
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag 
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
  ii.dbilldate <= '2020-04-16'
 and ii.dr=0 
 and ib.width  ='兼容'  
 and yw.busicode <> 's005'
 union all 
 select ii.csaleid ,
    ii.dbilldate as 日期,
       substr(to_char(to_date(ii.dbilldate,'yyyy-mm-dd'),'yyyy-mm-dd'),1,7)  as 月份,
    cu.deptname as 市场部,
    cu.n_deptname as 部门,
    cu.psnname as 业务员,
cu.pk_cumandoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
 cu.sf as 省 ,
       cu.cs as 市 ,
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
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag 
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
  ii.dbilldate >= '2020-04-17'
 and ii.dr=0 
 and ib.width  ='兼容' 
 --and ib.length ='硒鼓'
 --and ( cu.n_deptname like '%淘宝%' or cu.n_deptname like '%天猫%'or cu.n_deptname like '%拼多多%')--线上to C
 --and cu.custname like '%西藏%'and  cu.psnname like '%向鹏%' --向鹏大客户
  --and ib.invpinpai in ('方格博士') and   (ib.invname like '%CF41%' OR  ib.invname like '%CF50%' OR ib.invname like '%CF51%')             --and ck.storname ='1号库' 
 )ma  where ma.日期 between '2019-01-01'and '2020-11-30' group by 
 case when ma.品类 = '硒鼓' and ma.小类='黑色' then '黑色硒鼓'
     when ma.品类 = '硒鼓' and ma.小类='彩色' then '彩色硒鼓' 
     else ma.品类 end,
  ma.存货名称  ,ma.品牌,ma.月份,ma.是否放货
