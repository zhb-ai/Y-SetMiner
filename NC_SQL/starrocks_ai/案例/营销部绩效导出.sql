SELECT 
p.depart as 部门
,p.username as 姓名
,station as 岗位
,financial_month as 月份
,achievement as 总流水
,cost as 总成本
,gross_profit as 总毛利
,original_achievement as 原装流水
,supple_original_achievement as 原装补流水
,end_original_achievement as 补后原装流水
,original_achievement_ratio as 原装奖励比例
,original_bonus as 原装奖金
,compatible_achievement_A as 兼容A流水
,compatible_achievement_B as 兼容B流水
,supple_compatible_achievement as 补兼容流水
,end_compatible_achievement as 补后兼容流水
,compatible_achievement_A_ratio as 兼容A奖励比例
,compatible_achievement_B_ratio as 兼容B奖励比例
,compatible_bonus as 兼容奖金
,assessment_bonus as 绩效奖励 
,station_kpi as 岗位KPI
,baseline_bonus 保底奖励
,compatible_cartridge_bonus 后补奖励
-- ,pantum_bonus 奔图奖励
-- ,pantum_lanxum_bonus 奔图立思辰奖励
-- ,dead_stock_bonus 滞销品奖励
,assessment_coefficient  考核系数
,case when total is null then 0 else total end  绩效汇总
,case when old_total is null then 0 else old_total end   上月绩效
,case when total is null then 0 else total end - case when old_total is null then 0 else old_total end as 绩效差额
FROM yafo_employe as p 
left join yafo_employe_station as pe on p.id = pe.id
left join financial_nc_assessment_department_achievement as de 
on p.id = de.main_id
left join 
(select main_id,old_month,total as old_total from 
financial_nc_assessment_department_achievement ) as a 
on de.financial_month = a.old_month and p.id  = a.main_id
where p.markedepart like '%营销部%' 
and p.depart  <> '虚拟部' 
and financial_month = '2025-09'
 ORDER BY p.depart ,total desc 

