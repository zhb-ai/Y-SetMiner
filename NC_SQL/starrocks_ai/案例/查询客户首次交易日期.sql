select 
cu.pk_cumandoc,cu.custname,
max(ii.dbilldate) 末次交易日期,
min(ii.dbilldate) 首次交易日期,
sum(ib.nsummny) 总流水   
from nc5x.so_saleinvoice ii
join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode
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
left join nc5x.v_zlw_cust cuu 
on m.creceiptcorpid = cuu.pk_cumandoc
left join nc5x.bd_defdoc bd 
on ii.PK_DEFDOC5 = bd.PK_DEFDOC  
left join nc5x.bd_defdoc bdd 
on m.PK_DEFDOC5 = bdd.PK_DEFDOC  
where   
length(invcode) > 5 
and  ii.dr=0 
-- and  ii.dbilldate >= '2024-01-01'
group by cu.pk_cumandoc,cu.custname
