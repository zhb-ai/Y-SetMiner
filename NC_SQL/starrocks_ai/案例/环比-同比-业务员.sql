select nvl(t.ts,t2.ts),nvl(t.省,t2.省),t2.流水,t.流水,(t2.流水/t.流水)-1,
t2.毛利,
t.毛利,
(t2.毛利/t.毛利)-1 from 
( SELECT  ma.省,sum(ma.流水) 流水 ,sum(ma.毛利)  毛利,count(distinct ma.客户名称) as 客户数
 FROM  nc5x.JS_SALES ma
  WHERE ma.日期 between '2020-01-01'and '2020-12-31'  
  and 
  ma.大类='兼容'
  and substr(ma.日期,1,4)='2020'  
   GROUP BY
   ma.省 ) t
 full JOIN 
  (  SELECT  substr(ma.日期,6,2)as ts ,ma.省,sum(ma.流水) 流水,sum(ma.毛利) 毛利  FROM 
   nc5x.JS_SALES ma 
   WHERE ma.日期 between '2021-01-01'and '2021-12-31'  
   and ma.大类='兼容'
   and substr(ma.日期,1,4)='2021'  
    GROUP BY substr(ma.日期,6,2),ma.省 )  t2 
    ON t.ts = t2.ts  and t.省=t2.省
    

