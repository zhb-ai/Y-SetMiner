select ic_general_h.vbillcode ,
bd_billtype.billtypename as billtypename,
       bd_stordoc.storname as storname,
       ic_general_h.dbilldate as dbilldate,
       bd_invbasdoc.invpinpai as pp,
       bd_invbasdoc.length as length,
       bd_invbasdoc.width as width,
       bd_invbasdoc.invcode as invcode,
       bd_invbasdoc.invname as invname,
       sum(nvl(ic_general_b.noutnum, 0)) + sum(nvl(ic_general_b.ninnum, 0)) as noutnum,
       count(ic_general_h.dbilldate) as pl
  from nc5x.ic_general_h
 inner join nc5x.ic_general_b
    on (ic_general_h.cgeneralhid = ic_general_b.cgeneralhid
    and ic_general_b.dr = 0 
       and ic_general_h.fbillflag >= 3 
       and ic_general_h.cbilltypecode in ('4C', '4I', '4Y'))  ---, ))'45', '4A', '4E'
 inner join nc5x.bd_invbasdoc
    on (ic_general_b.cinvbasid = bd_invbasdoc.pk_invbasdoc)
 inner join nc5x.bd_billtype
    on (ic_general_h.cbilltypecode = bd_billtype.pk_billtypecode)
  left outer join nc5x.bd_stordoc
    on (ic_general_h.cwarehouseid = bd_stordoc.pk_stordoc)
where ic_general_h.dbilldate >= '2022-05-01' and ic_general_h.dbilldate <= '2022-07-31' and bd_stordoc.storname in ('1号库','京东云仓北京一号库','99库','天猫库','京东慧采-北京')
 group by bd_billtype.billtypename,
          bd_stordoc.storname,
          ic_general_h.dbilldate,
          bd_invbasdoc.invpinpai,
          bd_invbasdoc.length,
          bd_invbasdoc.width,
          bd_invbasdoc.invcode,
          bd_invbasdoc.invname,
          ic_general_h.vbillcode
 order by invcode asc, noutnum asc
 
 


--预计出预计入
select tmp.*,
       bd_produce.usableamount,
       bd_produce.usableamountbyfree,
       BD_STORDOC.storcode
  from (SELECT ic_atp.pk_corp,
               ic_atp.ccalbodyid,
               ic_atp.cinventoryid,
               invcode,
               ic_atp.cwarehouseid,
               sum(nvl(nmonum, 0)) nmonum,
               sum(nvl(nonrequirenum, 0)) nonrequirenum,
               sum(nvl(nonponum, 0)) nonponum,
               sum(nvl(nonwwnum, 0)) nonwwnum,
               sum(nvl(nonreceivenum, 0)) nonreceivenum,
               sum(nvl(nmponum, 0)) nmponum,
               sum(nvl(nonsonum, 0)) 订单承诺量, --订单承诺量
               sum(nvl(nonreceiptnum, 0)) nonreceiptnum,
               sum(nvl(npickmnum, 0)) npickmnum,
               sum(nvl(nrsvnum1, 0)) ntraninnum, --预计调拨入
               sum(nvl(nrsvnum2, 0)) ntranoutnum, --预计调拨出
               sum(nvl(nontranspraynum, 0)) nontranspraynum,
               sum(nvl(nonpreordernum, 0)) nonpreordernum
          from nc5x.ic_atp_f ic_atp,
               nc5x.         bd_stordoc,
               nc5x.         bd_invmandoc,
               nc5x.         bd_invbasdoc,
               nc5x.         bd_invcl
         where ic_atp.cwarehouseid = bd_stordoc.pk_stordoc(+)
           and ic_atp.cinventoryid = bd_invmandoc.pk_invmandoc
           and bd_invmandoc.pk_invbasdoc = bd_invbasdoc.pk_invbasdoc
           and bd_invbasdoc.pk_invcl = bd_invcl.pk_invcl
           and (ccalbodyid is not null and
               (cwarehouseid is null or isatpaffected = 'Y') and
               (0 = 0 and (ic_atp.pk_corp = '1006') -- and  (ccalbodyid = '1001A210000000000OPZ') and   (invcode = '060035')
               ))
         group by ic_atp.pk_corp,
                  ic_atp.ccalbodyid,
                  ic_atp.cinventoryid,
                  ic_atp.cwarehouseid,
                  invcode) tmp,
       
       (select * from nc5x.bd_produce where pk_corp = '1006') bd_produce,
       (select * from nc5x.BD_STORDOC where pk_corp = '1006') BD_STORDOC
 where tmp.cinventoryid = bd_produce.pk_invmandoc
   and tmp.ccalbodyid = bd_produce.pk_calbody
   and BD_STORDOC.PK_STORDOC = tmp.cwarehouseid and rownum <= 100
