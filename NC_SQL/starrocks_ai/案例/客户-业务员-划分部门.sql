select 业务员,市场部,部门划分 from (
SELECT 
 cum.deptname as 市场部,cum.n_deptname as 部门,cum.psnname as 业务员 ,
case when cum.deptname = '北京市场部'then '北京市场部'
when cum.deptname = '外阜市场部' and cum.n_deptname like '%南京%' then '南京分公司'
when cum.deptname = '外阜市场部' and cum.n_deptname like '%成都%' then '成都分公司'
when cum.deptname = '外阜市场部' and cum.n_deptname like '%西安%' then '西安分公司'
when cum.deptname = '外阜市场部' and cum.n_deptname like '%重庆%' then '重庆分公司'
when cum.deptname = '外阜市场部' and cum.n_deptname like '%哈尔滨%' then '哈尔滨分公司'
when cum.deptname = '外阜市场部' and cum.n_deptname like '%沈阳%' then '沈阳分公司'
else cum.deptname end 部门划分,
 count(distinct cum.pk_cumandoc) customer_num,row_number() over( partition by cum.psnname order by count(distinct cum.pk_cumandoc) desc) rn
FROM nc5x.bd_cubasdoc cub
join (select substr(deptcode,1,4) deptcode,
(case
when substr(dept.deptcode, 1, 6) in ( '030400','030441')  then
'区域销售部'
when substr(dept.deptcode, 1, 4) = '0303' then
'北京市场部'
when substr(dept.deptcode, 1, 4) = '0304' then
'外阜市场部'
when substr(dept.deptcode, 1, 2) = '10' then
'直营+微分销'
else dept.deptname end) deptname,
dept.deptname n_deptname,
psn.psnname psnname,
pay.termname,
pay.termid,
cum.*
from nc5x.bd_cumandoc cum
join nc5x.bd_deptdoc dept
on cum.pk_respdept1 = dept.pk_deptdoc
join nc5x.bd_psndoc psn
on cum.pk_resppsn1 = psn.pk_psndoc
left join nc5x.bd_payterm pay
on cum.pk_payterm = pay.pk_payterm
and cum.dr = 0
where cum.custflag in ('0', '2')
and cum.pk_corp = '1006'
and cum.dr = 0)cum
on cub.pk_cubasdoc = cum.pk_cubasdoc and cub.dr = 0
where (1=1) and  (case when (cum.sealflag is not null or length(ltrim(rtrim(cum.sealflag))) > 0 ) then 'Y' ELSE 'N' END )  ='N'
and  cum.deptname in ('渠道部','北京市场部','区域销售部','平台业务部','外阜市场部') and not (cum.n_deptname = '售后服务中心') and not (cum.psnname = '共享客户')
group by cum.deptname ,cum.n_deptname,cum.psnname
)
where rn = 1 
group by 业务员,市场部,部门划分

-- and cum.psnname = '王海侠'
-- and cum.deptname <>  '直营+微分销' 
-- and cub.custname like '%山西星辰创客网络科技有限公司%'

-- and cum.psnname not in ('李东伟','刘喜丹','殷宁娜','闫广军') 
-- and cum.deptname =  '平台业务部' 
-- and cub.pk_cubasdoc = 'NC772007090416101222'
-- and cub.custname like '%长沙以不凡电脑有限%'


