----***客户合作缺陷报表***----

select 
f.合作推进 as pick_up_advance,
f.客户主键  as customer_primary_key,
f.客户名称  as customer_name,
f.部门 as department ,
f.业务员 as sales_man ,
f.兼容硒鼓金额 as cp_cartridge_achievement ,
f.兼容其他金额 as cp_other_achievement,
f.兼容合计金额 as cp_sum_achievement ,
f.原装合计金额 as original_sum_achievement
 from nc5x.pick_up_advance as f


select * from (
select case when ma.original_sum_achievement= 0 and ma.cp_sum_achievement <>0 then '兼容客户无原装'
            when ma.cp_sum_achievement = 0 then '无兼容合作'
            when ma.cp_cartridge_achievement = 0 then '缺少兼容硒鼓合作' else null  end pick_up_advance,ma.*
 from  (
select 
ma.客户主键,
ma.客户名称,
ma.部门,
ma.业务员,
sum(case when ma.大类='兼容'and ma.品类='硒鼓' then ma.价税合计 else 0 end ) cp_cartridge_achievement,
sum(case when ma.大类='兼容'and ma.品类<>'硒鼓' then ma.价税合计 else 0 end )cp_other_achievement,
sum(case when ma.大类='兼容' then ma.价税合计 else 0 end )cp_sum_achievement,
sum(case when ma.大类='原装' then ma.价税合计 else 0 end )original_sum_achievement
 from (
select ii.csaleid ,
ib.pk_invbasdoc ,
 ii.VRECEIPTCODE ,
    ii.dbilldate as 日期 ,
    substr(ii.dbilldate,1,7) as 月份 ,
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
 where
  ii.dbilldate <='2020-04-16'
  and  yw.busicode <> 's005'
 and ii.dr=0 
 and ib.width  ='兼容'
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
 )ma  where  ma.日期 >= to_char(sysdate-365,'yyyy-mm-dd')
group by ma.客户主键,
ma.客户名称,
ma.部门,
ma.业务员 )ma  ) ma    
where ma.pick_up_advance is  not null
