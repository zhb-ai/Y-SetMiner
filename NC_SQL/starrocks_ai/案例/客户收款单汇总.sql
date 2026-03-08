
select 
(select custname from nc5x.bd_cubasdoc where pk_cubasdoc = hbbm)  客户名称,
width 大类,
djlxbm,
年,
sum(jfbbje)  借方本币金额,
sum(bbye) 本币余额,
sum(yushou) as 预收,

sum(dfbbje) as 贷方本币收款,
sum(jfb) as 借方本币销售额
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
dfbbje ,
jfbbje as jfb,
djlxbm,
substr(billdate,1,4) as 年, 
to_Number(replace(ter.termname,'天',''))  tyzq,
to_date(to_char( sysdate,'yyyy-mm-dd'),'yyyy-mm-dd')-to_date(fb.billdate,'yyyy-mm-dd')-to_Number(replace(ter.termname,'天','')) as czq
from nc5x.arap_djfb fb
left join nc5x.bd_payterm ter on fb.sfkxyh = ter.pk_payterm
left join nc5x.bd_invbasdoc ch on fb.cinventoryid = ch.pk_invbasdoc
where fb.djdl in ('ys', 'sk')
and fb.hbbm = '0001C1100000001C0H2Q'
-- and nvl(fb.bbye, 0) <> 0
and fb.dr = 0
-- and djlxbm = '23A3'

-- and fb.isverifyfinished = 'N'
-- and fb.djbh  = 'SK2311150006'
) rf
where 1=1 
group by hbbm ,width ,djlxbm,年
