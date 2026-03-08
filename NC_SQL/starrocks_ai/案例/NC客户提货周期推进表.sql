select 
合作推进 as  pick_up_advance
,客户主键 as customer_primary_key
,客户名称 as customer_name
,部门 as department
,业务员 as sales_man
,兼容硒鼓金额 as cp_cartridge_achievement
,兼容其他金额 as cp_other_achievement
,兼容合计金额 as cp_sum_achievement
,原装合计金额 as cp_sum_achievement
from (
select case when ma.原装合计金额= 0 and ma.兼容合计金额 <>0 then '兼容客户无原装'
when ma.兼容合计金额 = 0 then '无兼容合作'
when ma.兼容硒鼓金额 = 0 then '缺少兼容硒鼓合作' else null  end 合作推进,ma.*
from  (
select
ma.客户主键,
ma.客户名称,
ma.部门,
ma.业务员,
sum(case when ma.大类='兼容'and ma.品类='硒鼓' then ma.价税合计 else 0 end ) 兼容硒鼓金额,
sum(case when ma.大类='兼容'and ma.品类<>'硒鼓' then ma.价税合计 else 0 end )兼容其他金额,
sum(case when ma.大类='兼容' then ma.价税合计 else 0 end )兼容合计金额,
sum(case when ma.大类='原装' then ma.价税合计 else 0 end )原装合计金额
from (
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
ib.nsummny as 价税合计,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌
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
where
ii.dbilldate >= to_char(sysdate-365,'yyyy-mm-dd')
and ii.dr=0
and ib.width  ='兼容'
 )ma 
group by ma.客户主键,
ma.客户名称,
ma.部门,
ma.业务员 )ma  ) ma
where ma.合作推进 is  not null;
