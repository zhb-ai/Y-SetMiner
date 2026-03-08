select    d.存货名称 ,d.客户名称,d.月份,d.年份, sum(d.销量) 销量,sum(d.流水) 流水,count(d.客户名称) 单量,max(d.销量) 单次最大值 from   (
select  d.存货名称 ,d.客户名称 ,d.销量,d.流水,case when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='01' then '1月'
 when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='02' then '2月'
    when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='03' then '3月'
       when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='04' then '4月'  
          when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='05' then '5月'
              when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='06' then '6月'
              when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='07' then '7月'
                when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='08' then '8月'
                    when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='09' then '9月'  
                       when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='10' then '10月'
                          when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='11' then '11月'
                             when substr(to_char(d.日期,'YYYY-MM-DD'),6,2)='12' then '12月'end 月份    ,
                              case when  substr(to_char(d.日期,'YYYY-MM-DD'),1,4)='2019'  then '2019'
           when  substr(to_char(d.日期,'YYYY-MM-DD'),1,4)='2020'  then '2020' end 年份  
                              from nc5x.V_YFHC_JY01 d  where  to_char(d.日期,'YYYY-MM-DD') between '2019-10-01'and '2020-05-28')d
           group by  d.存货名称 ,d.客户名称 ,d.月份,d.年份  order by 单量 desc
