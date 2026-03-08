select 
m.vreceiptcode,
ib.cupsourcebillbodyid ,
ib.CORIGINALBILLCODE,
ii.VRECEIPTCODE 发票号,
ii.dbilldate as 日期,
ib.nnumber as 数量,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ck.storname as 库房,
nvl(m.pk_defdoc6,th.pk_defdoc6) as 收货人,
nvl(m.vdef20,th.vdef20) as 收货地址,
nvl(m.pk_defdoc16,th.pk_defdoc16) 销售省份,
nvl(m.pk_defdoc20,th.pk_defdoc20) 销售城市
from nc5x.so_saleinvoice ii
join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode,ib.nmny,csourcebillid,cupsourcebillbodyid
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.sm_user  su1 
on m.coperatorid = su1.cuserid
left join nc5x.v_zlw_cust cuu 
on m.creceiptcorpid = cuu.pk_cumandoc
left join nc5x.bd_defdoc bd 
on ii.PK_DEFDOC5 = bd.PK_DEFDOC  
left join nc5x.bd_defdoc bdd 
on m.PK_DEFDOC5 = bdd.PK_DEFDOC  
left join (
select distinct aa.vsourcecode,
aa.vreceiptcode as th_order,
m.pk_defdoc6  ,
m.vdef20  ,
m.pk_defdoc16 ,
m.pk_defdoc20 ,
aa.vreceiptcode from nc5x.so_apply aa 
left join  nc5x.so_sale m
on aa.vsourcecode = m.vreceiptcode
) th
on ib.coriginalbillcode = th.th_order
where   
ii.dr=0 
and length(invcode) >= 5 
and cu.deptname =  '直营+微分销'
and  ii.dbilldate >= '2024-03-01'
and  ii.dbilldate <= '2024-03-31'
-- and ib.nnumber < 0 
-- and ib.coriginalbillcode = '3U2402230024'

