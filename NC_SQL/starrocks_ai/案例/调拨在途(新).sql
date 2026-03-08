select 
invcode,
仓库,
sum(nshouldinnum) as nshouldinnum 
FROM
(
select 
case when storcode in ('052','051') then '成都仓'
when storcode in ('013','005') then '科贸3A003'
when storcode in ('017','019') then '沈阳仓'
when storcode in ('084','150','001') then '北京仓'
when storcode in ('022','092') then '南京仓'
when storcode in ('076','145') then '中山仓'
else storname end 仓库,
h.vbillcode,h.CGENERALHID,h.CWAREHOUSEID,b.cinvbasid,b.nshouldinnum,h.TMAKETIME,ck.storcode,iv.invcode ,ck.storname,iv.invname
from nc5x.ic_general_h  h 
join nc5x.ic_general_b b  on  h.CGENERALHID=b.CGENERALHID 
LEFT join nc5x.bd_stordoc ck on h.cwarehouseid = ck.pk_stordoc
LEFT join nc5x.bd_invbasdoc iv on b.cinvbasid= iv.pk_invbasdoc 
where h.CBILLTYPECODE ='4E' AND h.DACCOUNTDATE IS NULL  and h.dr=0 and b.dr=0 
and storcode in ('058','056','043','017','019','084','022','005','013','092','150','020','051','052','001','076','145')
) 

GROUP BY invcode,storcode, 仓库
order by 1 asc

