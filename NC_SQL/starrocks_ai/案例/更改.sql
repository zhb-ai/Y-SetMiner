select count(1)
  from nc5x.ic_general_h
 inner join nc5x.ic_general_b
    on (nc5x.ic_general_h.cgeneralhid = nc5x.ic_general_b.cgeneralhid and
       nc5x.ic_general_b.dr = 0 and nc5x.ic_general_h.fbillflag >= 3 and
       nc5x.ic_general_h.cbilltypecode in ('45', '4A', '4E' ))
 inner join nc5x.bd_invbasdoc
    on (nc5x.ic_general_b.cinvbasid = nc5x.bd_invbasdoc.pk_invbasdoc)
 inner join nc5x.bd_billtype
    on (nc5x.ic_general_h.cbilltypecode = nc5x.bd_billtype.pk_billtypecode)
  left outer join nc5x.bd_stordoc
    on (nc5x.ic_general_h.cwarehouseid = nc5x.bd_stordoc.pk_stordoc)
where dbilldate >= '2020-02-01' and dbilldate <= '2020-03-31' 
 group by bd_billtype.billtypename,
          bd_stordoc.storname,
          ic_general_h.dbilldate,
          bd_invbasdoc.invpinpai,
          bd_invbasdoc.length,
          bd_invbasdoc.width,
          bd_invbasdoc.invcode,
          bd_invbasdoc.invname
 order by invcode , noutnum asc
