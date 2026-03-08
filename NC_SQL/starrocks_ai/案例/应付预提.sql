select 
(select pk_cubasdoc from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) 客户主键,
(select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm)  客户名称,
(select PSNNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  业务员 ,
(select N_DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  部门 ,
(select DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  市场部 ,
invcode as 存货编码,
invname as 存货名称,
width 大类,
invpinpai 品牌,
length 品类 ,
height 小类,
sum(nvl(dfbbje,0))  贷方本币金额,
sum(nvl(bbye,0)) 本币余额,
sum(nvl(yufu,0)) as 预付,
sum(abs(nvl(dfbbje,0)) - abs(nvl(yufu,0))) as 剩余预提
from (select ddh,djbh,
fb.hbbm,
fb.billdate,
djdl,
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
and fb.isverifyfinished = 'N'  and custname <> '北京东方超技科技发展有限公司' and substr(ddh,1,4) in ('FDYT', 'FDFH') 
) rf
  where 1=1 --  and hbbm = '0001C11000000018ZOMQ'
 group by  hbbm,invcode,invname,invpinpai,height,width,length
