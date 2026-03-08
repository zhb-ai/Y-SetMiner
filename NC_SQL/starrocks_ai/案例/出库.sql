select  bd_billtype.billtypename 出入库方式,
ic_general_h.vbillcode 单据号,
       ic_general_h.daccountdate 签字日期,
       ic_general_h.dbilldate  单据日期,
       ic_general_h.taccounttime 签字时间,
       ic_general_h.tmaketime 制单时间,
       bd_stordoc.storname 出库库房,
       to_char(to_date(ic_general_h.ts,'yyyy-mm-dd hh24:mi:ss'),'hh24') 时间戳,
       to_char(to_date(ic_general_h.ts,'yyyy-mm-dd hh24:mi:ss'),'hh24:mi') 时分,
       replace(to_char(to_date(ic_general_h.tmaketime,'yyyy-mm-dd hh24:mi:ss'),'hh24:mi'),':','.')小时,
replace(to_char(to_date(ic_general_h.TS,'yyyy-mm-dd hh24:mi:ss'),'hh24:mi'),':','.')小时1,
       sum(nc5x.ic_general_b.noutnum)  数量
  from nc5x.ic_general_h 
left join nc5x.ic_general_b 
    on (nc5x.ic_general_h.cgeneralhid = nc5x.ic_general_b.cgeneralhid and
       nc5x.ic_general_b.dr = 0 and nc5x.ic_general_h.fbillflag >= 3)
left join nc5x.bd_invbasdoc
    on (nc5x.ic_general_b.cinvbasid = nc5x.bd_invbasdoc.pk_invbasdoc)
left join nc5x.bd_billtype
    on (nc5x.ic_general_h.cbilltypecode = nc5x.bd_billtype.pk_billtypecode)
  left outer join nc5x.bd_stordoc       
    on (nc5x.ic_general_h.cwarehouseid = nc5x.bd_stordoc.pk_stordoc)
    left join  nc5x.sm_user cu on ic_general_h.coperatorid =cu.cuserid
    left join  (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,cg.lowestprice,cg.refsaleprice , cg.def3
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc) cg
        on ic_general_b.cinventoryid = cg.pk_invmandoc 
        where 
         dbilldate between '2020-08-01' and '2020-12-31' 
         and bd_billtype.billtypename in ('库存调拨出库单','库存销售出库单') 
         and nc5x.ic_general_b.dr = 0 and nc5x.ic_general_h.fbillflag >= 3
         --and nc5x.ic_general_b.noutnum <0
         group by  bd_billtype.billtypename ,
           ic_general_h.daccountdate ,
       ic_general_h.dbilldate ,
       ic_general_h.taccounttime ,
       ic_general_h.tmaketime ,
       ic_general_h.vbillcode,
       bd_stordoc.storname ,
       replace(to_char(to_date(ic_general_h.ts,'yyyy-mm-dd hh24:mi:ss'),'hh24:mi'),':','.'),
        to_char(to_date(ic_general_h.ts,'yyyy-mm-dd hh24:mi:ss'),'hh24:mi'),
       to_char(to_date(ic_general_h.ts,'yyyy-mm-dd hh24:mi:ss'),'hh24')
        -- select * from  nc5x.so_squaredetail  where  vreceiptcode = 'XC1807252658'
   
        
