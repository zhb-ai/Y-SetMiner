select nvl (gg.月份,dd.月份)as 月份 ,nvl(gg.出货编码,dd.存货编码) as 存货编码 ,nvl(gg.出货名称,dd.存货名称) as 存货名称 ,nvl(gg.出货品牌,dd.品牌) as 品牌,nvl(gg.出货品类,dd.品类) as 品类, nvl (gg.小类,dd.小类)as 小类,gg.总出货数量,dd.入库数量,nvl(gg.仓库,dd.仓库) as 仓库
from(
select 
substr(to_char(to_date(aa.dinvoicedate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,7) as 月份,
--substr(to_char(to_date(aa.dinvoicedate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,10)as 日期,
cc.invcode as 存货编码,
cc.invname as 存货名称,
 ck.storname as 仓库 ,
sum(bb.ninvoicenum) as 入库数量,
cc.length as 品类,
cc.invpinpai as 品牌,
cc.width as 大类,
cc.height as 小类
from nc5x.po_invoice_b bb
join nc5x.po_invoice aa
  on bb.cinvoiceid = aa.cinvoiceid
join nc5x.bd_invbasdoc cc
  on bb.cbaseid = cc.pk_invbasdoc
    left join nc5x.bd_stordoc ck
    on bb.cwarehouseid = ck.pk_stordoc
where aa.dinvoicedate >='2021-01-06'
and aa.dinvoicedate <='2021-01-06'
and cc.width='兼容'
and bb.ninvoicenum > 0
group by cc.invcode,cc.invname,cc.invpinpai,cc.length,ck.storname ,cc.width  , cc.height,substr(to_char(to_date(aa.dinvoicedate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,7)-- ,substr(to_char(to_date(aa.dinvoicedate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,10)
) dd
full join 
(select cd.invcode 出货编码,sum(cd.nnumber) 总出货数量,cd.invname 出货名称,cd.invpinpai 出货品牌,cd.length 出货品类,cd.height 小类--,ii.dbilldate as 日期
,substr(to_char(to_date(ii.dbilldate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,7) as 月份
--substr(to_char(to_date(ii.dbilldate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,10)as 日期
,ck.storname as 仓库
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ch.invname,ch.invcode,ch.width,ch.invpinpai,ch.height,ch.length
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc) cd
            on cd.csaleid = ii.csaleid
             left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
  where ii.dbilldate between  '2021-01-06'and '2021-01-06'
  and cd.width='兼容'
  and ii.dr =0 
  group by cd.invcode,cd.invname,cd.invpinpai,cd.length,  ck.storname ,cd.height
 ,substr(to_char(to_date(ii.dbilldate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,7)
--substr(to_char(to_date(ii.dbilldate ,'yyyy-mm-dd'),'yyyy-mm-dd'),1,10)
 ) gg 
on dd.存货编码 = gg.出货编码 
and dd.月份= gg.月份
and gg.仓库=dd.仓库 
