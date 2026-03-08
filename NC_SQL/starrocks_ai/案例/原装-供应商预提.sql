select 
to_char(sysdate,'yyyy-mm-dd') 插入日期,
(select pk_cubasdoc from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) 客户主键,
(select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm)  客户名称,
(select PSNNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  业务员 ,
(select N_DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  部门 ,
(select DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  市场部 ,
abs(sum(返点预提金额)) 返点预提金额,
abs(sum(返点确认金额)) 返点确认金额,
abs(sum(返点返回金额)) 返点返回金额
from 
(select 
case when substr(ddh,1,4) = 'FDFH' then '返点返回'
when substr(ddh,1,4) = 'FDYT' then '返点预提'
when substr(ddh,1,4) = 'FDQR' then '返点确认' 
else '应付' end 预提单据类型,
CASE WHEN substr(ddh,1,4) = 'FDYT' THEN nvl((case when fb.djdl = 'yf' then fb.bbye else 0end),0) ELSE 0 END 返点预提金额,
CASE WHEN substr(ddh,1,4) = 'FDQR' THEN nvl((case when fb.djdl = 'yf' then fb.bbye else 0end),0) ELSE 0 END 返点确认金额,
CASE WHEN substr(ddh,1,4) = 'FDFH' THEN nvl((case when fb.djdl = 'fk' then fb.bbye else 0end),0) ELSE 0 END 返点返回金额,
fb.JOBID,
FB.szxmid,
fb.ddh,
fb.djbh,
fb.hbbm,
fb.billdate,
fb.djdl,
--zb.zyx10,
custname,
ch.invpinpai,
ch.height,
ch.width,
ch.length,
ch.invname,
ch.invcode,
fb.zy,
nvl((case when fb.cinventoryid = '0001C1100000000ZOVE0' then fb.bbye else 0 end ),0) yfye,
nvl((case when fb.djdl = 'yf' then fb.dfbbje else 0 end ),0) dfbbje,
nvl((case when fb.djdl = 'yf' then fb.bbye else 0 end),0) bbye,
nvl((case when fb.djdl = 'fk' then fb.bbye else 0end),0) yufu,
to_Number(replace(ter.termname,'天',''))  tyzq,
to_date(to_char( sysdate,'yyyy-mm-dd'),'yyyy-mm-dd')-to_date(fb.billdate,'yyyy-mm-dd')-to_Number(replace(ter.termname,'天','')) as czq,
so.businame,
so.psnname
from nc5x.arap_djfb fb
-- left join nc5x.arap_djzb zb on fb.vouchid  = zb.vouchid   
left join nc5x.bd_payterm ter on fb.sfkxyh = ter.pk_payterm
left join 
（SELECT * FROM nc5x.so_sale so left join nc5x.bd_busitype bt on so.cbiztype= bt.pk_busitype
left join  nc5x.bd_psndoc  us  
on us.pk_psndoc= so.cemployeeid
) so 
on fb.ddh=so.vreceiptcode
left join nc5x.bd_cubasdoc gm on gm.pk_cubasdoc = hbbm
left join nc5x.bd_invbasdoc ch on fb.cinventoryid = ch.pk_invbasdoc
where fb.djdl in ('yf', 'fk')
and fb.hbbm not in
(select pk_cubasdoc
from nc5x.bd_cubasdoc
where custname in ('') )
and nvl(fb.bbye, 0) <> 0
and fb.dr = 0 
and fb.isverifyfinished = 'N' and  substr(ddh,1,4) in ('FDFH','FDYT','FDQR') ) 
group by hbbm
