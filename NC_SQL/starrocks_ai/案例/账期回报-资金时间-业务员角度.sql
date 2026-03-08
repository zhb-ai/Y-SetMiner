select  to_char(sysdate ,'yyyy-mm-dd') as 当前日期,nvl(d.部门,f.部门) as 部门,nvl(d.业务员,f.业务员)as 业务员,d.资金时间,d.价税合计,d.拟平均应收,d.拟单月流水,f.毛利率 from 
(select ma.部门,
 case when  ma.业务员 in ('郑鹏鹏','张桂龙','王鲁','孙希宝') then  ma.部门 
   else ma.业务员 end 业务员,sum(ma.资金时间) 资金时间 ,sum(ma.价税合计) 价税合计,sum(ma.资金时间)/28 as 拟平均应收,sum(ma.价税合计)/1.1 as  拟单月流水 
from (
select distinct 
case when  cg.invpinpai like '%佳能%' then '佳能'
     when  cg.invpinpai like '%惠普%' then '惠普'
                 when  cg.invpinpai like '%懿智通%' then '懿智通'
     when  cg.invpinpai like '%智通%' then '智通'
       when  cg.invpinpai like '%盈佳%' then '盈佳'

             when  cg.invpinpai like '%扬帆耐立%' then '扬帆耐立'
                when  cg.invpinpai like '%方格博士%' then '方格博士' else   cg.invpinpai end 品牌分类,
a.custname as 客户名称,
a.deptname as 市场部,
a.n_deptname as 部门,
a.psnname as 业务员,
s.vreceiptcode as 订单号,
nvl(sb.nsummny,0) as 价税合计,
s.dapprovedate as 发货日期,
yw.businame as 业务类型,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
nvl(sb.nnumber,0) as 数量,
b.verifyfinisheddate as 回款日期,
nvl(TO_NUMBER(TO_DATE(b.verifyfinisheddate,'yyyy-mm-dd hh24:mi:ss')- TO_DATE(s.dapprovedate,'yyyy-mm-dd hh24:mi:ss')),0) as 回款时长,
nvl(sb.nsummny * TO_NUMBER(TO_DATE(b.verifyfinisheddate,'yyyy-mm-dd hh24:mi:ss')- TO_DATE(s.dapprovedate,'yyyy-mm-dd hh24:mi:ss')),0) as 资金时间
from nc5x.so_saleorder_b sb
join nc5x.so_sale s
on s.csaleid =sb.csaleid
join nc5x.bd_invbasdoc cg
on cg.pk_invbasdoc =sb.cinvbasdocid
join (select a.custname,a.deptname,a.n_deptname,a.psnname,s.csaleid
  from nc5x.v_zlw_cust a
  join nc5x.so_sale s
  on s.ccustomerid = a.PK_CUMANDOC)a
on a.csaleid=sb.csaleid
join (select b.verifyfinisheddate,b.ddh,s.vreceiptcode,s.csaleid
  from nc5x.arap_djfb b
  join nc5x.so_sale s
  on s.vreceiptcode = b.ddh)b
on b.csaleid = sb.csaleid
join nc5x.bd_busitype yw
on s.cbiztype = yw.pk_busitype
where b.verifyfinisheddate between to_char(sysdate -29 ,'yyyy-mm-dd')
and  to_char(sysdate  - 1 ,'yyyy-mm-dd')
and length(cg.invcode) <> 4
and cg.width in ('兼容','原装','打印机')  
and (a.n_deptname not like '%京东%'or a.n_deptname not like '%京喜%'or a.n_deptname not like '%拼多多%'or a.n_deptname not like '%天猫%'or a.n_deptname not like '%淘宝%')
) ma  group by ma.部门,ma.业务员)d

full join 
(select 
 ma.部门,
 case when  ma.业务员 in ('郑鹏鹏','张桂龙','王鲁','孙希宝') then  ma.部门 
   else ma.业务员 end 业务员 ,sum(ma.毛利)/sum(ma.流水) as 毛利率
 from (
select ma.客户编码,ma.客户名称,ma.存货编码,ma.存货名称,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.业务类型,ma.业务属性,ma.本币价税合计,ma.批发价税合计,ma.价税合计,nvl(ma.流水,0) 流水,nvl(ma.毛利,0) 毛利 ,ma.成本,ma.市场部,ma.部门,ma.业务员,to_date(ma.日期,'yyyy-MM-dd') as 日期,ma.省,ma.市
from (select
cu.custcode as 客户编码,
cu.custname as 客户名称,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
yw.businame as 业务类型,
js.vdef11 as 业务属性,
case when js.blargessflag = 'Y' then 0 else js.nsummny end  as 本币价税合计,
js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,
js.ncostmny as 成本,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
cu.sf as 省,
cu.cs as 市
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc us
on us.pk_psndoc= js.cemployeeid
where
  length(cg.invcode) <> 4
  and js.dr=0
  and '流水' <> 'null'
  and cg.width in ('兼容','原装','打印机')
  and cu.custname is not null 
  ) ma 
where ma.流水 <> 0 and  ma.日期 between to_char(sysdate -29 ,'yyyy-mm-dd') and to_char(sysdate -1 ,'yyyy-mm-dd')) ma group by ma.部门,ma.业务员) f on f.业务员 = d.业务员 
