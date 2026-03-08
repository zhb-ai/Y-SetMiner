
SELECT 
p.depart as 部门
,real_name as 业务员
,station as 岗位
,financial_month as 财务月份
,achievement 总流水		

,gross_profit 总毛利
,other_profit 原装毛利
,original_achievement_ratio 原装奖励比例
,original_bonus  原装奖金
,compatible_profit  兼容毛利
,compatible_achievement_B_ratio 兼容奖励比例
,haocaiwang_profit  好采网毛利
,compatible_bonus  as '兼容&商务奖金'
,assessment_bonus as 绩效奖励
,station_kpi as 岗位KPI
,baseline_bonus as 保底奖励
,compatible_cartridge_bonus 后补奖励
,assessment_coefficient 考核系数
,case when total is null then 0 else total end 绩效汇总
,case when old_total is null then 0 else old_total end 上月绩效
,case when total is null then 0 else total end - case when old_total is null then 0 else old_total end as 绩效差额
FROM yafo_employe as p 
left join yafo_employe_station as pe on p.id = pe.id
left join key_customer_department_achievement_reach as de 
on p.id = de.main_id
left join 
(select main_id,old_month,total as old_total from 
key_customer_department_achievement_reach ) as a 
on de.financial_month = a.old_month and p.id  = a.main_id
 where p.markedepart  like '%大客户部%' 
 and p.depart  <> '虚拟部' 
 and financial_month = '2024-12'
 
 
 
 
 
 