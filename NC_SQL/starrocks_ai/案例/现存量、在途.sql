SELECT cc.*,nvl(db.调拨在途,0) 调拨在途,cz.预计到货日期,nvl(采购在途,0) 采购在途 FROM (
select 存货编码,storname,storcode,sum(结存数量)结存数量  from (
select
bb.invcode 存货编码,
SUM(dd.nonhandnum) 结存数量 ,
dd.storname ,
dd.storcode
from nc5x.bd_invbasdoc bb
left join ( select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc,cc.storname,cc.storcode
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc where cc.dr =0  ) dd
on dd.cinvbasid = bb.pk_invbasdoc
where dd.storcode in ('001','051','056','020','017','022','058','01702','04302','099','01302','05602','05103','02202')
GROUP BY bb.invcode ,dd.storname, dd.storcode  )
group by 存货编码,storname,storcode )  CC
left join (
select 
invcode,
storcode,
storname,
sum(nshouldinnum) 调拨在途
FROM
(select ck.storcode,ck.storname,c.cinvbasid,iv.invcode,c.nshouldinnum,c.TMAKETIME,iv.invname from (
select h.CGENERALHID,h.CWAREHOUSEID,b.cinvbasid,b.nshouldinnum,h.TMAKETIME from nc5x.ic_general_h  h 
join nc5x.ic_general_b b  on  h.CGENERALHID=b.CGENERALHID 
where h.CBILLTYPECODE ='4E' AND h.DACCOUNTDATE IS NULL  and h.dr=0 and b.dr=0 
) c LEFT join nc5x.bd_stordoc ck on c.cwarehouseid = ck.pk_stordoc
 LEFT join nc5x.bd_invbasdoc iv on c.cinvbasid= iv.pk_invbasdoc ) 
WHERE storcode in  ('001','051','056','020','017','022','058','01702','04302','099','01302','05602','05103','02202')
GROUP BY invcode,cinvbasid ,storname,storcode) db
on cc.存货编码 = db.invcode and cc.storcode = db.storcode
left join (
select 
distinct
rc.storcode,
rc.storname,
ch.invcode,
min(pb.dplanarrvdate) 预计到货日期,
sum(pb.nordernum)  采购在途
from nc5x.po_order p 
left join 
(select pb.corderid,pb.cwarehouseid, pb.dclosedate,pb.naccumstorenum,case when dplanarrvdate<='2023-01-31' then null else dplanarrvdate end dplanarrvdate ,cbaseid,nordernum from nc5x.po_order_b pb 
) pb
on  p.corderid =pb.corderid 
join nc5x.bd_invbasdoc ch
on pb.cbaseid = ch.pk_invbasdoc                                                                                                                                                                                                 
left join nc5x.po_invoice_b bb
on pb.corderid = bb.corderid
left join nc5x.Bd_Stordoc rc
on pb.cwarehouseid= rc.pk_stordoc
join nc5x.bd_cubasdoc xx
on p.cvendorbaseid =xx.pk_cubasdoc
where 
bb.ninvoicenum is  null
and p.dauditdate >= to_char(sysdate-30,'yyyy-mm-dd') 
and  p.forderstatus = 3 
and  ch.width in ('原装','打印机','兼容') 
and p.dr = 0
and pb.dclosedate is null 
and pb.naccumstorenum is null 
and rc.storcode in  ('001','051','056','020','017','022','058','01702','04302','099','01302','05602','05103','02202')
group by rc.storcode,rc.storname,ch.invcode
) cz on  cc.存货编码 = cz.invcode and cc.storcode = cz.storcode where not ( 结存数量 = 0 and  调拨在途 is null and 采购在途 is null )









