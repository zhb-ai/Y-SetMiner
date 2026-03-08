select nvl(ma.市场部分配,'其他'),nvl(ma.业务员分配,'其他') ,ma.制单日期,
sum(兼容流水)兼容流水 ,
sum(原装流水 )原装流水 ,
sum(毛利)毛利,sum(服务费)服务费,sum(订单数)订单数,sum(客户数量)客户数量   from (
select  ma.*,
case when ma.市场部 ='直营+微分销' and 专管业务员 in ('孙希宝','张学兵','刘鱼浩') then '电商业务' 
when ma.市场部 ='直营+微分销'   and 专管业务员 ='崔小帅' then '线上业务'
when ma.市场部 ='直营+微分销'  then '线上业务'
when ma.市场部 = 'SI业务部' then 'SI业务部' 
when ma.市场部 = '大客户部' then '客户业务'
when ma.市场部 = '平台业务部' then '平台业务'
when ma.市场部 not in ('渠道部','外阜市场部','北京市场部','区域销售部') then '其他'
when ma.部门 like '%南京%' then '南京分公司'
when ma.部门 like '%西安%' then '西安分公司'
when ma.部门 like '%沈阳%' then '沈阳分公司'
when ma.部门 like '%哈尔滨%' then '哈尔滨分公司'
when ma.部门 like '%成都%' then '成都分公司'
when ma.部门 like '%重庆%' then '重庆分公司'
else ma.市场部 end 市场部分配,
case when ma.市场部 = '直营+微分销' and 专管业务员   not in ('孙希宝','张学兵','刘鱼浩','崔小帅') then 部门
else 专管业务员 end 业务员分配
from (
select 专管业务员,市场部,部门, 制单日期,sum(case when 大类 in ('兼容') then 流水 else 0 end )兼容流水 ,
sum(case when 大类 in ('原装','打印机') then 流水 else 0 end )原装流水 ,
sum(case when 大类 in ('兼容') then 毛利 else 0 end )毛利,sum(case when 大类 in ('兼容') then 服务费 else 0 end)服务费,sum(case when 大类 in ('兼容') then 订单数 else 0 end)订单数,sum(case when 大类 in ('兼容') then 客户数量 else 0 end)客户数量
from (
select 
cu.psnname as 专管业务员,
cu.deptname 市场部,
cu.n_deptname 部门, 
cg.width 大类,
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
where fb.billdate  >= to_char(sysdate - 10,'yyyy-mm-dd') 
and length(cg.invcode) <> 4 
and cg.width in ('兼容' ,'原装','打印机')
and fb.dr=0 
and cu.psnname is not null 
group by 
cu.psnname,
cu.deptname,
cu.n_deptname,
cg.width,
fb.billdate 
union all 
select 
cu.psnname as 专管业务员,
cu.deptname 市场部,
cu.n_deptname 部门, 
cg.width 大类,
sum(ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) as 流水,
sum(ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)-js.ncostmny) AS 毛利,
sum((case  nvl2( TRIM(REGEXP_replace(js.VBODYDEF8,'[0-9|+|-|.]','')),0,1)  when 1 then to_number(js.VBODYDEF8) else 0 end )*(js.nnewbalancenum/abs(js.nnewbalancenum)))AS 服务费,
fb.billdate AS 制单日期,
count(distinct js.vreceiptcode) as 订单数,
count(distinct js.ccustomerid) as 客户数量
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
where  fb.billdate  >= to_char (sysdate - 10,'yyyy-mm-dd')
and length(cg.invcode) <> 4  
and cg.width in ('兼容' ,'原装','打印机')
and fb.dr=0 
and cu1.psnname is null
group by 
cu.psnname,
cu.deptname,
cu.n_deptname,
fb.billdate,cg.width ) ma 
group by 专管业务员,市场部,部门,制单日期
)ma 
)ma group by ma.市场部分配,ma.业务员分配,ma.制单日期 
