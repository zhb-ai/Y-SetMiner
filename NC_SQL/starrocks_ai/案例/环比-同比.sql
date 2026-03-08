
select --(j.流水/s.流水)-1 as 流水环比, (j.毛利/s.毛利)-1 as 毛利环比, (j.客户数/s.客户数)-1 as 客户数环比,
* from 
(select case when 1=1  then '1' else '0' end  日期 , sum(ma.流水) as 流水 ,sum(ma.毛利) as 毛利,count(distinct ma.客户编码) as 客户数  from nc5x.js_sales ma where ma.日期 between '2020-01-01'and '2020-12-31' )s
  LEFT JOIN 
  (select case when 1=1 then '1' else '0' end  日期  ,sum(ma.流水)as 流水 ,sum(ma.毛利) as 毛利,count(distinct ma.客户编码) as 客户数  from nc5x.js_sales ma where ma.日期 between '2019-01-31'and '2019-12-31' )j
  on s.日期 = j.日期
