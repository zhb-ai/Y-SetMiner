 select  cu.部门,cu.业务员,cu.客户主键,
  sum(case when cu.cse =  '一到三天' then cu.余额 else null end) 一到三天,
  sum(case when cu.cse =  '四到十天' then cu.余额 else null end) 四到十天,
      sum(case when cu.cse =  '十一到三十天' then cu.余额 else null end) 十一到三十天,
         sum( case when cu.cse =  '三十到九十天' then cu.余额 else null end) 三十到九十天,
              sum(case when cu.cse =  '九十天以上' then cu.余额 else null end )九十天以上,
               sum( case when cu.cse =  '正常' then cu.余额 else null end) 账期内,
                  sum(cu.余额) as 余额,sum(预收)as 预收,sum(超期应收)as 超期应收
    from (
select cu.部门 ,cu.业务员,cu.客户主键 ,cu.czq,
  case when cu.czq>0 then '账期外'else '账期内'end 是否超期, 
  case when cu.czq>0 and cu.czq<=3 then '一到三天'
  when  cu.czq>3 and cu.czq<=10 then '四到十天'
    when cu.czq>10 and cu.czq<=30 then '十一到三十天'
    when cu.czq>30 and cu.czq<=90 then '三十到九十天'
     when cu.czq>90  then '九十天以上'else '正常'end cse ,
  sum(本币余额 )as 余额,
  sum(预收) as 预收,
  sum (case when cu.czq>0 then 本币余额 else 0 end )as 超期应收
   from (select 
       (select pk_cubasdoc from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) 客户主键,
       (select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) 客户名称,
       ddh as 订单号 ,
       (CASE djdl WHEN 'ys' then '应收' when 'sk' then '收款' else '其他' END) AS 单据大类,
       (select PSNNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  业务员,
       (select N_DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  部门,
       billdate as 单据日期,
       czq ,
       businame as 订单类型,
       tyzq as 通用账期,
       sum(jfbbje) 借方本币金额,
       sum(bbye) 本币余额,
       sum(-abs(yushou)) as 预收,
       zy 备注
  from (select ddh,
               fb.hbbm,
               fb.billdate,
               djdl,
               fb.zy,
               (case
                 when fb.cinventoryid = '0001C1100000000ZOVE0' then
                  fb.bbye
                 else
                  0
               end) yfye,
               (case
                 when fb.djdl = 'ys' then
                  fb.jfbbje
                 else
                  0
               end) jfbbje,
               (case
                 when fb.djdl = 'ys' then
                  fb.bbye
                 else
                  0
               end) bbye,
               (case
                 when fb.djdl = 'sk' then
                  fb.bbye
                 else
                  0
               end) yushou,
               to_Number(replace(ter.termname,'天',''))  tyzq, --通用账期
               to_date(to_char( sysdate,'yyyy-mm-dd'),'yyyy-mm-dd')-to_date(fb.billdate,'yyyy-mm-dd')-to_Number(replace(ter.termname,'天','')) as czq,
               so.businame
          from nc5x.arap_djfb fb
          left join nc5x.bd_payterm ter on fb.sfkxyh = ter.pk_payterm
          left join 
          （SELECT * FROM nc5x.so_sale so left join nc5x.bd_busitype bt on so.cbiztype= bt.pk_busitype) so 
          on fb.ddh=so.vreceiptcode
         where fb.djdl in ('ys', 'sk')
           and fb.hbbm not in
               (select pk_cubasdoc
                  from nc5x.bd_cubasdoc
                 where custname in
                       (''))
          and nvl(fb.bbye, 0) <> 0
           and fb.dr = 0
         and fb.isverifyfinished = 'N'
          ) rf
  where 1=1 --and  (select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) ='兰州天利政和电子科技有限公司'
 group by  ddh, billdate,czq, djdl,tyzq, zy, hbbm,businame order by 1) cu where  cu.客户名称 <>'智通仁和办公拼购专营店' 
  group by   cu.部门 ,cu.业务员,cu.客户主键 ,cu.czq ) cu group by  cu.部门, cu.业务员, cu.客户主键
