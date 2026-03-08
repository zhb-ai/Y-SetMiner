 select   nvl ( t.ts, t2.ts )  ,
  nvl ( t.负责人, t2.负责人 ) ,
  t2.流水 ,
  t.流水 ,
  ( t2.流水 / t.流水 ) - 1 ,
  t2.毛利  ,
  t.毛利  ,
  ( t2.毛利 / t.毛利 ) - 1  from 
( 
SELECT
   ma.ts ,
    ma.负责人,
    SUM ( ma.流水 ) 流水 ,
    SUM ( ma.毛利 ) 毛利
from (
    
  select substr ( ma.日期, 6, 2 ) AS ts ,ma.打印品牌,
    case when ma.打印品牌 in ('爱普生打印机','爱普生','利盟') then '白晓野'
--when ma.打印品牌 in () then '巩林波'
when ma.打印品牌 in ('佳能打印机','惠普打印机（渠道）','其它品牌打印机') then '何路超'
  when ma.打印品牌 in ('三星','OKI','施乐','兄弟','富士通','联想') then '侯志祥'
      when ma.打印品牌 in ('惠普黑鼓','奔图打印机','奔图','其它打印类') then '李晶伟'
         when ma.打印品牌 in ('佳能复印类','施乐复印类','三星复印类','柯尼卡美能达','东芝','夏普','理光','京瓷','其他复印类') then '王红曼'
          when ma.打印品牌 in ('惠普打印机（行业）') then '姚辉铭'
          when ma.打印品牌 in ('惠普墨盒','佳能墨盒','佳能硒鼓') then '张京'
            when ma.打印品牌 in ('惠普彩鼓') then '姚辉铭'
               when ma.打印品牌 in ('扬帆耐立','智通') then '张曦'
        when ma.打印品牌 in ('盈佳') then '苗凯'
                   when ma.打印品牌 in ('懿品','懿智通','方格博士','懿品佳') then '张鹏鹏' else '分组异常' end 负责人,sum(ma.流水) 流水,sum(ma.毛利) 毛利  
                     from 
(
select ma.*, 
    case when ma.大类 ='打印机' and ma.品牌 = '爱普生' then '爱普生打印机'
   when ma.大类 ='打印机' and ma.品牌 like  '%佳能%' then '佳能打印机'
     when ma.大类 ='打印机' and ma.品牌 = '奔图'then '奔图打印机'
     when ma.大类 ='打印机' and ma.品牌 like '%惠普%' and ma.小类 = '行业' then '惠普打印机（行业）'
       when ma.大类 ='打印机' and ma.品牌 like '%惠普%'  and ma.小类 = '渠道' then '惠普打印机（渠道）'
         when ma.大类 ='打印机' then '其它品牌打印机'
         when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '彩色' then '惠普彩鼓'
            when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '黑色' then '惠普黑鼓'
               when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '墨盒','墨水','介质')  then '惠普墨盒'
                 when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '粉仓','硒鼓')  then '三星'
                     when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '墨盒','墨水','介质')  then '佳能墨盒'
                       when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '硒鼓','粉仓','配件')  then '佳能硒鼓'
                          when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '硒鼓','粉仓')  then '施乐'
                           when   ma.大类 ='原装' and ma.品牌 = '奔图' then '奔图'
                             when   ma.大类 ='原装' and ma.品牌 = '兄弟' then '兄弟'
                                when   ma.大类 ='原装' and ma.品牌 = '富士通' then '富士通'
                                   when   ma.大类 ='原装' and ma.品牌 = 'OKI' then 'OKI'
                                      when   ma.大类 ='原装' and ma.品牌 = '联想' then '联想'
                                         when   ma.大类 ='原装' and ma.品牌 = '爱普生' then '爱普生'
                                            when   ma.大类 ='原装' and ma.品牌 = '利盟' then '利盟'
                                          when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '佳能复印类'
                                            when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '施乐复印类'
                                              when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '三星复印类'
                                               when   ma.大类 ='原装' and ma.品牌 in ('柯尼卡美能达','德凡')   then '柯尼卡美能达'
                                                 when   ma.大类 ='原装' and ma.品牌 in ('东芝')   then '东芝'
                                                  when   ma.大类 ='原装' and ma.品牌 in ('夏普')   then '夏普'
                                                     when   ma.大类 ='原装' and ma.品牌 in ('理光')   then '理光'
                                                        when   ma.大类 ='原装' and ma.品牌 in ('京瓷')   then '京瓷'
                                                        when   ma.大类 ='原装' and ma.品牌 in ('理想','震旦','松下')   then '其他复印类'
                                                          when   ma.大类 ='原装'  then '其它打印类'
                                                            when   ma.大类 ='兼容' and ma.品牌 = '懿品' then '懿品'
                                                               when   ma.大类 ='兼容' and ma.品牌 = '懿品佳' then '懿品佳'
                                                                  when   ma.大类 ='兼容' and ma.品牌 like '%方格博士%' then '方格博士'
                                                                     when   ma.大类 ='兼容' and ma.品牌 like '%懿智通%' then '懿智通'
                                                                        when   ma.大类 ='兼容' and ma.品牌 like '%盈佳%' then '盈佳'
                                                                           when   ma.大类 ='兼容' and ma.品牌 like '%扬帆耐立%' then '扬帆耐立'
                                                                             when   ma.大类 ='兼容' and ma.品牌 like '%智通%' then '智通'
                                                                               else '其他-异常'end  打印品牌  from  nc5x.JS_SALES ma 
     WHERE  ma.大类 in ( '兼容','原装','打印机')
    AND substr ( ma.日期, 1, 4 ) = '2020' 
    ) ma group by  ma.日期,substr ( ma.日期, 6, 2 ) ,ma.打印品牌 )ma 
    group by    ma.ts ,
    ma.负责人 ) t
  FULL JOIN (
    SELECT
   ma.ts ,
    ma.负责人,
    SUM ( ma.流水 ) 流水 ,
    SUM ( ma.毛利 ) 毛利
from (
    
  select substr ( ma.日期, 6, 2 ) AS ts ,ma.打印品牌,
    case when ma.打印品牌 in ('爱普生打印机','爱普生','利盟') then '白晓野'
--when ma.打印品牌 in () then '巩林波'
when ma.打印品牌 in ('佳能打印机','惠普打印机（渠道）','其它品牌打印机') then '何路超'
  when ma.打印品牌 in ('三星','OKI','施乐','兄弟','富士通','联想') then '侯志祥'
      when ma.打印品牌 in ('惠普黑鼓','奔图打印机','奔图','其它打印类') then '李晶伟'
         when ma.打印品牌 in ('佳能复印类','施乐复印类','三星复印类','柯尼卡美能达','东芝','夏普','理光','京瓷','其他复印类') then '王红曼'
          when ma.打印品牌 in ('惠普打印机（行业）') then '姚辉铭'
          when ma.打印品牌 in ('惠普墨盒','佳能墨盒','佳能硒鼓') then '张京'
            when ma.打印品牌 in ('惠普彩鼓') then '姚辉铭'
               when ma.打印品牌 in ('扬帆耐立','智通') then '张曦'
        when ma.打印品牌 in ('盈佳') then '苗凯'
                   when ma.打印品牌 in ('懿品','懿智通','方格博士','懿品佳') then '张鹏鹏' else '分组异常' end 负责人,sum(ma.流水) 流水,sum(ma.毛利) 毛利  
                     from 
(
select ma.*, 
    case when ma.大类 ='打印机' and ma.品牌 = '爱普生' then '爱普生打印机'
   when ma.大类 ='打印机' and ma.品牌 like  '%佳能%' then '佳能打印机'
     when ma.大类 ='打印机' and ma.品牌 = '奔图'then '奔图打印机'
     when ma.大类 ='打印机' and ma.品牌 like '%惠普%' and ma.小类 = '行业' then '惠普打印机（行业）'
       when ma.大类 ='打印机' and ma.品牌 like '%惠普%'  and ma.小类 = '渠道' then '惠普打印机（渠道）'
         when ma.大类 ='打印机' then '其它品牌打印机'
         when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '彩色' then '惠普彩鼓'
            when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '黑色' then '惠普黑鼓'
               when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '墨盒','墨水','介质')  then '惠普墨盒'
                 when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '粉仓','硒鼓')  then '三星'
                     when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '墨盒','墨水','介质')  then '佳能墨盒'
                       when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '硒鼓','粉仓','配件')  then '佳能硒鼓'
                          when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '硒鼓','粉仓')  then '施乐'
                           when   ma.大类 ='原装' and ma.品牌 = '奔图' then '奔图'
                             when   ma.大类 ='原装' and ma.品牌 = '兄弟' then '兄弟'
                                when   ma.大类 ='原装' and ma.品牌 = '富士通' then '富士通'
                                   when   ma.大类 ='原装' and ma.品牌 = 'OKI' then 'OKI'
                                      when   ma.大类 ='原装' and ma.品牌 = '联想' then '联想'
                                         when   ma.大类 ='原装' and ma.品牌 = '爱普生' then '爱普生'
                                            when   ma.大类 ='原装' and ma.品牌 = '利盟' then '利盟'
                                          when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '佳能复印类'
                                            when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '施乐复印类'
                                              when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '三星复印类'
                                               when   ma.大类 ='原装' and ma.品牌 in ('柯尼卡美能达','德凡')   then '柯尼卡美能达'
                                                 when   ma.大类 ='原装' and ma.品牌 in ('东芝')   then '东芝'
                                                  when   ma.大类 ='原装' and ma.品牌 in ('夏普')   then '夏普'
                                                     when   ma.大类 ='原装' and ma.品牌 in ('理光')   then '理光'
                                                        when   ma.大类 ='原装' and ma.品牌 in ('京瓷')   then '京瓷'
                                                        when   ma.大类 ='原装' and ma.品牌 in ('理想','震旦','松下')   then '其他复印类'
                                                          when   ma.大类 ='原装'  then '其它打印类'
                                                            when   ma.大类 ='兼容' and ma.品牌 = '懿品' then '懿品'
                                                               when   ma.大类 ='兼容' and ma.品牌 = '懿品佳' then '懿品佳'
                                                                  when   ma.大类 ='兼容' and ma.品牌 like '%方格博士%' then '方格博士'
                                                                     when   ma.大类 ='兼容' and ma.品牌 like '%懿智通%' then '懿智通'
                                                                        when   ma.大类 ='兼容' and ma.品牌 like '%盈佳%' then '盈佳'
                                                                           when   ma.大类 ='兼容' and ma.品牌 like '%扬帆耐立%' then '扬帆耐立'
                                                                             when   ma.大类 ='兼容' and ma.品牌 like '%智通%' then '智通'
                                                                               else '其他-异常'end  打印品牌  from  nc5x.JS_SALES ma 
     WHERE  ma.大类 in ( '兼容','原装','打印机')
    AND substr ( ma.日期, 1, 4 ) = '2021' 
    ) ma group by  ma.日期,substr ( ma.日期, 6, 2 ) ,ma.打印品牌 )ma 
    group by    ma.ts ,
    ma.负责人 ) t2 on t.ts=t2.ts and  t.负责人 =  t2.负责人
    
