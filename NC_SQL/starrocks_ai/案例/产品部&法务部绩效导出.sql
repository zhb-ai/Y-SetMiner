 SELECT 
p.depart 部门
,real_name 姓名
,station  岗位
,financial_month	财务月份
,original_achievement_ratio	岗位系数
,win_bidding_num	中标个数
,100 中标个数系数
,contract_save_num	录入及存档数量
,authorize_num	出具授权的数量
,tencent_num	标讯录入平台数量
,2 标讯其他系数
,one_level	一级数量
,one_ratio	一级比例
,two_level	二级数量
,commerce_two_level	电商二级数量
,three_level	三级数量
,two_ratio	二三级比例
,four_level	四级数量
,four_ratio	四级比例
,quotation_four_level	报价四级数量
,bj_four_ratio	报价四级比例
,five_num	五级数量
,five_ratio	五级比例
,other_num	其他等级
,other_ratio	其他比例
,assessment_bonus	绩效奖励
,station_kpi	岗位KPI
,assessment_coefficient	考核系数
,case when total is null then 0 else total end 绩效汇总
,case when old_total is null then 0 else old_total end 上月绩效
,case when total is null then 0 else total end - case when old_total is null then 0 else old_total end as 绩效差额
FROM yafo_employe as p 
left join yafo_employe_station as pe on p.id = pe.id
left join w_tencent_product_achievement as de 
on p.id = de.main_id
left join 
(select main_id,old_month,total as old_total from 
w_tencent_product_achievement ) as a 
on de.financial_month = a.old_month and p.id  = a.main_id
left join w_tencent_product_ratio as tp 
on p.id  = tp.main_id 
 where p.markedepart  like '%产品部%' 
 and p.depart  <> '虚拟部' 
 and p.is_delete is null
 and financial_month = '2025-09' ORDER BY p.depart ,total desc 
 