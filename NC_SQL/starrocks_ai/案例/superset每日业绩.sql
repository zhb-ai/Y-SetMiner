select  ma.*,
case when ma.市场部 ='直营+微分销' and 专管业务员 in ('孙希宝','张学兵','刘鱼浩') then '电商业务' 
when ma.市场部 ='直营+微分销'   and 专管业务员 ='崔小帅' then '线上业务'
when ma.市场部 ='直营+微分销'  then '线上业务'
when ma.市场部 = 'SI业务部' then '外阜市场部' 
when ma.市场部 = '大客户部' then '客户业务'
when ma.市场部 = '平台业务部' then '平台业务'
when ma.市场部 not in ('渠道部','外阜市场部','北京市场部','区域销售部') then '其他'
else ma.市场部 end 市场部分配,
case 
when ma.市场部 = '直营+微分销' and 专管业务员 not in ('孙希宝','张学兵','刘鱼浩','崔小帅') then 部门
else 专管业务员 end 业务员分配
from (
select 专管业务员,业务员,市场部,部门, 制单日期,sum(流水)流水 ,sum(毛利)毛利,sum(服务费)服务费,sum(订单数)订单数,sum(客户数量)客户数量
from (
select 
cu.psnname as 专管业务员,
us.psnname as 业务员,
cu.deptname 市场部,
cu.n_deptname 部门, 
sum(ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) as 流水,
sum(ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)-js.ncostmny) AS 毛利,
sum((case  nvl2( TRIM(REGEXP_replace(js.VBODYDEF8,'[0-9|+|-|.]','')),0,1)  when 1 then to_number(js.VBODYDEF8) else 0 end )*(js.nnewbalancenum/abs(js.nnewbalancenum)))AS 服务费,
fb.billdate AS 制单日期,
count(distinct js.vreceiptcode ) as 订单数,
count(distinct js.ccustomerid ) as 客户数量
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc ) cg
on js.cinventoryid = cg.pk_invmandoc 
LEFT join nc5x.bd_busitype yw 
on js.cbiztype = yw.pk_busitype 
LEFT join nc5x.v_zlw_cust cu 
on js.ccustomerid = cu.pk_cumandoc 
LEFT join nc5x.arap_djfb fb 
on fb.cksqsh= js.csourcebillbodyid and fb.dr = 0 
left join nc5x.bd_psndoc us 
on us.pk_psndoc= js.cemployeeid 
where fb.billdate  >= to_char(sysdate - 7,'yyyy-mm-dd') 
and length(cg.invcode) <>4 
and cg.width='兼容' 
and fb.dr=0 
and cu.psnname is not null 
group by 
cu.psnname,
us.psnname,
cu.deptname,
cu.n_deptname,
fb.billdate 
union all 
select 
cu.psnname as 专管业务员,
us.psnname as 业务员,
cu.deptname 市场部,
cu.n_deptname 部门, 
sum(ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) as 流水,
sum(ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)-js.ncostmny) AS 毛利,
sum((case  nvl2( TRIM(REGEXP_replace(js.VBODYDEF8,'[0-9|+|-|.]','')),0,1)  when 1 then to_number(js.VBODYDEF8) else 0 end )*(js.nnewbalancenum/abs(js.nnewbalancenum)))AS 服务费,
fb.billdate AS 制单日期,
count(distinct js.vreceiptcode ) as 订单数,
count(distinct js.ccustomerid ) as 客户数量
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc ) cg
on js.cinventoryid = cg.pk_invmandoc 
LEFT join nc5x.bd_busitype yw 
on js.cbiztype = yw.pk_busitype 
LEFT join nc5x.arap_djfb fb 
on fb.cksqsh= js.csourcebillbodyid and fb.dr = 0 
LEFT join nc5x.v_zlw_cust cu1 
on js.ccustomerid = cu1.pk_cumandoc 
left join nc5x.bd_psndoc us 
on us.pk_psndoc= js.cemployeeid 
LEFT join  (select distinct cu.deptname ,cu.n_deptname ,cu.psnname from nc5x.v_zlw_cust cu) cu  
on us.psnname = cu.psnname
where  fb.billdate  >= to_char(sysdate-7,'yyyy-mm-dd') 
and length(cg.invcode) <> 4 
and cg.width='兼容' 
and fb.dr=0 
and cu1.psnname is null 
group by 
cu.psnname,
us.psnname,
cu.deptname,
cu.n_deptname,
fb.billdate ) ma 
group by 专管业务员,业务员,市场部,部门,制单日期
)ma

