
select 
(select pk_cubasdoc from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) 客户主键,
(select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) 客户名称,
ddh as 订单号 ,
(CASE djdl WHEN 'ys' then '应收' when 'sk' then '收款' else '其他' END) AS 单据大类,
nvl((select PSNNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm),psnname)   业务员,
case when (select deptname from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  is null  then '大客户部'  else  (select deptname from nc5x.v_zlw_cust where pk_cubasdoc = hbbm) end  市场部,
case when (select N_DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  is null  then '大客户部'  else (select N_DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  end 部门,
billdate as 单据日期,
czq ,
verifyfinisheddate 核销日期 ,
businame as 订单类型,
tyzq as 通用账期,
sum(jfbbje) 借方本币金额,
sum(dfbbje) 贷方本币金额,
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
so.businame,
so.psnname,
dfbbje,
fb.verifyfinisheddate
from nc5x.arap_djfb fb
left join nc5x.bd_payterm ter on fb.sfkxyh = ter.pk_payterm
left join 
（SELECT * FROM nc5x.so_sale so left join nc5x.bd_busitype bt on so.cbiztype= bt.pk_busitype
left join  nc5x.bd_psndoc  us  
on us.pk_psndoc= so.cemployeeid
) so 
on fb.ddh=so.vreceiptcode
where fb.djdl in ('ys', 'sk')
and fb.hbbm not in
(select pk_cubasdoc
from nc5x.bd_cubasdoc
where custname in
(''))
and nvl(fb.bbye, 0) =  0
and fb.dr = 0
-- and fb.isverifyfinished = 'N' 
and fb.djbh  <> 'SK1403070006'
and verifyfinisheddate >= '2025-04-01'
) rf
where 1=1 
--and  (select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) ='兰州天利政和电子科技有限公司'
group by  ddh, billdate,czq, djdl,tyzq, zy, hbbm,businame,psnname,verifyfinisheddate order by 1 -- where    cu.业务员 = '孙希宝'-- where  cu.客户名称 <>'智通仁和办公拼购专营店' 
