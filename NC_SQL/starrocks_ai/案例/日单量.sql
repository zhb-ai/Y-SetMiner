select    d.存货名称 ,d.客户名称,d.日期, sum(d.销量) 销量,sum(d.流水) 流水 from   (
select  d.存货名称 ,d.客户名称 ,d.销量,d.流水,d.日期     from nc5x.V_YFHC_JY01 d  where  to_char(d.日期,'YYYY-MM-DD') between '2020-01-01'and '2020-05-20')d
           group by  d.存货名称 ,d.客户名称 ,d.日期 
