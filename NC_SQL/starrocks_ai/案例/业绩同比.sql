select nvl(t.ts,t2.ts) THE_MONTH  , 
nvl(t.大类,t2.大类) THE_CLASS ,
nvl(t.业务员,t2.业务员) SalesName,
t2.流水 SalesVolumeThisYear,
t.流水 SalesVolumeOldYear
,case when abs(t.流水) =0 then 0 else (abs(t2.流水)/abs(t.流水))-1 end YearOverYearVolume ,
t2.毛利 ProfitThisYear,
t.毛利 ProfitOldYear,
case when abs(t.毛利) =0 then  0 else  (abs(t2.毛利)/abs(t.毛利))-1end YearOverYearProfit 
from 
( SELECT  substr(ma.日期,6,2)as ts ,ma.业务员, ma.大类,sum(ma.流水) 流水 ,sum(ma.毛利)  毛利
 FROM  nc5x.JS_SALES ma
  WHERE ma.日期 between to_char(trunc(sysdate -365 ,'yyyy'),'yyyy-mm-dd')and to_char(sysdate-365,'yyyy-mm-dd')  
  and 
  ma.大类 in ('兼容','原装','打印机')
  and substr(ma.日期,1,4)='2022'  
   GROUP BY substr(ma.日期,6,2) ,
   ma.业务员, ma.大类 ) t
 full JOIN 
  (  SELECT  substr(ma.日期,6,2)as ts ,ma.业务员, ma.大类,sum(ma.流水) 流水,sum(ma.毛利) 毛利  FROM 
   nc5x.JS_SALES ma 
   WHERE ma.日期 between to_char(trunc(sysdate,'yyyy'),'yyyy-mm-dd')and to_char(last_day(sysdate), 'yyyy-mm-dd')  
   and ma.大类 in ('兼容','原装','打印机') 
   and substr(ma.日期,1,4)='2023'  
    GROUP BY substr(ma.日期,6,2),ma.业务员 , ma.大类  )  t2 
  ON t.ts = t2.ts  and t.业务员 = t2.业务员 and t.大类 = t2.大类
  
