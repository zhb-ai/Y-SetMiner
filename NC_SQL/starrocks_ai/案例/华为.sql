select  月份 as financial_month ,nvl(省,'北京') as province ,区域 as region , 业务模式 as business_model ,类别 as big_category ,sum(价税合计) as  achievement ,sum(流水)流水,sum(毛利)毛利 
from  (
select
case when cg.width = '打印机' and cg.length = '显示器' then '显示器' 
when cg.width = '原装' then '耗材'
when cg.invname like '%台式机%'or cg.invname like '%笔记本%' then '电脑'
when cg.width = '打印机' then '打印机'
else '其他' end 类别,
case when cu.deptname ='直营+微分销' then '线上' else '线下' end  as 业务模式,
case when cu.deptname <> '直营+微分销' then 
case when cu.deptname in ('北京市场部','渠道部') then '北京'
when (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  like '%哈尔滨%'or (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  like '%沈阳%'or  cu.deptname = '区域销售部' then '东北+区域'
when (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  like '%南京%' then '南京'
when  (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  like '%西安%' 
or (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  like '%成都%'
or  (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  like '%重庆%' then '川陕渝' 
else '平台+项目' end else case when cu.n_deptname like '%京东慧采%' or  cu.n_deptname like '%京喜%' then '慧采' else 'POP' end end 区域,
cg.width as 大类,
cg.length as 品类,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,  
substr((case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ),1,7) 月份,

cu.sf as 省,
cu.cs as 市
from nc5x.so_squaredetail js
left join  nc5x.so_square zjs on js.csaleid = zjs.csaleid 
LEFT join (
select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ch.unitweight,ch.unitvolume,
cg.refsaleprice as 批发售价
,cg.def5 as 代理价 
,cg.lowestprice   as 最低限价
from nc5x.bd_invmandoc cg
join nc5x.bd_invbasdoc ch
on cg.pk_invbasdoc = ch.pk_invbasdoc )cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype  yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust  cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc  us
on us.pk_psndoc= js.cemployeeid
left join nc5x.so_sale hl
on js.csourcebillid = hl.csaleid
left join nc5x.bd_stordoc dd
on js.cwarehouseid = dd.pk_stordoc
where 
length(cg.invcode) >= 5
and js.dr=0
and cg.invpinpai = '华为'
and cg.width in ('打印机','原装')
and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) between '2022-01-01' and '2022-12-31'
) ma 
group by 月份,省,区域, 业务模式,类别

