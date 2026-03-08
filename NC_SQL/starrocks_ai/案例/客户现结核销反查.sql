
select 
(select pk_cubasdoc from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm) 客户主键,
(select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm)  客户名称,
ddh as  订单号,
djbh as 应收单号,
(CASE djdl WHEN 'ys' then '应收' when 'sk' then '收款' else '其他' END) AS 单据大类,
(select PSNNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  业务员,
(select N_DEPTNAME from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  部门,
(select deptname from nc5x.v_zlw_cust where pk_cubasdoc = hbbm)  市场部,
billdate as 单据日期,
verifyfinisheddate 核销完成日期,
czq AS 超账期,
businame as 订单类型,
tyzq as 通用账期,
width 大类,
invpinpai 品牌,
length 品类 ,
height 小类,
invname 存货名称,
invcode 存货编码,
jfshl 数量,
hsdj 单价,
sum(jfbbje)  借方本币金额,
sum(bbye) 本币余额,
sum(yushou) as 预收,
zy 备注
from (select ddh,
fb.hbbm,
fb.billdate,
djdl,
djbh,
fb.zy,
ch.invpinpai,
ch.height,
ch.width,
ch.length,
ch.invname,
ch.invcode,
fb.verifyfinisheddate,
(case
 when fb.cinventoryid = '0001C1100000000ZOVE0' then
  fb.bbye
 else
  0
end ) yfye,
(case
 when fb.djdl = 'ys' then
  fb.jfbbje
 else
  0
end ) jfbbje,
(case
 when fb.djdl = 'ys' then
  fb.hsdj
 else
  0
end ) hsdj,
(case
 when fb.djdl = 'ys' then
  fb.jfshl
 else
  0
end ) jfshl,
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
to_Number(replace(ter.termname,'天',''))  tyzq,
to_date(to_char( sysdate,'yyyy-mm-dd'),'yyyy-mm-dd')-to_date(fb.billdate,'yyyy-mm-dd')-to_Number(replace(ter.termname,'天','')) as czq,
so.businame
from nc5x.arap_djfb fb
left join nc5x.bd_payterm ter on fb.sfkxyh = ter.pk_payterm
left join nc5x.bd_invbasdoc ch on fb.cinventoryid = ch.pk_invbasdoc
left join 
（SELECT * FROM nc5x.so_sale so left join nc5x.bd_busitype bt on so.cbiztype= bt.pk_busitype) so 
on fb.ddh=so.vreceiptcode
where fb.djdl in ('ys', 'sk')
and fb.hbbm not in
(select pk_cubasdoc
  from nc5x.bd_cubasdoc
 where custname in 
       (''))
-- and nvl(fb.bbye, 0) <> 0
and fb.dr = 0
and fb.djbh  <> 'SK1403070006'
and fb.hbbm in ('0001C11000000018C5PM',
'0001C110000000195NVP',
'0001C11000000019RZBJ',
'1006C11000000020J1CF',
'1006C1100000006BH7MG',
'1006C1100000008ISJW9',
'1006C110000000AV1KQ2',
'1006C110000000FGAWQ5',
'1006C110000000FZKI53',
'1006C110000000G3CEDO',
'1006C110000000GDPJIP',
'1006C110000000GRJOI2',
'1006C110000000H1PHU3',
'1006C110000000HKSQGQ',
'1006C110000000HRARE1',
'1006C110000000IYWBIR',
'1006C110000000J6B963',
'1006C110000000JAQKBL',
'1006C110000000JAQWGM',
'1006C110000000JL0WYI',
'1006C110000000JP4EEO',
'1006C110000000JP8L4F',
'1006C110000000K6NO2O',
'1006C110000000KHHVSQ',
'1006C110000000LBSK0O',
'1006C110000000LCWZ4I',
'1006C110000000LHAPDB',
'1006C110000000M1UA78',
'1006C110000000M3FMOW',
'1006C110000000MEZC6T',
'1006C110000000MFLISC')
-- and fb.isverifyfinished = 'N' 
) rf
where 1=1 
group by  ddh, billdate,czq, djdl,tyzq, zy,djbh, hbbm,businame,invpinpai,height,width,length,invname,invcode,jfshl,hsdj  ,verifyfinisheddate
