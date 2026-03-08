/*采购发票金额*/
select 供应商id, 供应商名称,sum(数量) 数量,sum(价税合计)价税合计  from (
select
ch.pk_invbasdoc as 存货主键,
aa.dinvoicedate as 日期,
substr(aa.dinvoicedate,1,7) as 月份,
yy.custname as 供应商名称,
ch.invcode as 存货编码,
ch.invname as 存货名称,
bb.ninvoicenum as 数量,
bb.nsummny as 价税合计,
bb.nsummny/bb.ninvoicenum as 单价,
ch.length as 品类,
ch.invpinpai as 品牌,
case when ch.width ='打印机' and ch.invpinpai = '爱普生' then '爱普生打印机'
when ch.width ='打印机' and ch.invpinpai like  '%佳能%' then '佳能打印机'
when ch.width ='打印机' and ch.invpinpai = '奔图'then '奔图打印机'
when ch.width ='打印机' and ch.invpinpai like '%华为%'  then '华为打印机'
when ch.width ='打印机' and ch.invpinpai like '%惠普%' and ch.height = '行业' then '惠普打印机（行业）'
when ch.width ='打印机' and ch.invpinpai like '%惠普%'  and ch.height = '渠道' then '惠普打印机（渠道）'
when ch.width ='打印机' then '其它品牌打印机'
when ch.invpinpai in ('钉钉','法珞斯')then  '其它品牌打印机'
when   ch.width ='原装' and ch.invpinpai like '%惠普%'  and ch.length in ( '硒鼓','配件') and ch.height = '彩色' then '惠普彩鼓'
when   ch.width ='原装' and ch.invpinpai like '%惠普%'  and ch.length in ( '硒鼓','配件') and ch.height = '黑色' then '惠普黑鼓'
when   ch.width ='原装' and ch.invpinpai like '%惠普%'  and ch.length in ( '墨盒','墨水','介质')  then '惠普墨盒'
when   ch.width ='原装' and ch.invpinpai = '三星' and ch.length in ( '粉仓','硒鼓')  then '三星'
when   ch.width ='原装' and ch.invpinpai like  '%佳能%' and ch.length in ( '墨盒','墨水','介质')  then '佳能墨盒'
when   ch.width ='原装' and ch.invpinpai like  '%佳能%' and ch.length in ( '硒鼓','粉仓','配件')  then '佳能硒鼓'
when   ch.width ='原装' and ch.invpinpai = '施乐' and ch.length in ( '硒鼓','粉仓')  then '施乐'
when   ch.width ='原装' and ch.invpinpai = '奔图' then '奔图'
when   ch.width ='原装' and ch.invpinpai = '兄弟' then '兄弟'
when   ch.width ='原装' and ch.invpinpai = '华为' then '华为'
when   ch.width ='原装' and ch.invpinpai = '立思辰' then '立思辰'
when   ch.width ='原装' and ch.invpinpai = '富士通' then '富士通'
when   ch.width ='原装' and ch.invpinpai = 'OKI' then 'OKI'
when   ch.width ='原装' and ch.invpinpai = '联想' then '联想'
when   ch.width ='原装' and ch.invpinpai = '爱普生' then '爱普生'
when   ch.width ='原装' and ch.invpinpai = '利盟' then '利盟'
when   ch.width ='原装' and ch.invpinpai like  '%佳能%' and ch.length in ( '复印硒鼓','复印碳粉盒')  then '佳能复印类'
when   ch.width ='原装' and ch.invpinpai = '施乐' and ch.length in ( '复印硒鼓','复印碳粉盒')  then '施乐复印类'
when   ch.width ='原装' and ch.invpinpai = '三星' and ch.length in ( '复印硒鼓','复印碳粉盒')  then '三星复印类'
when   ch.width ='原装' and ch.invpinpai in ('柯尼卡美能达','德凡')   then '柯尼卡美能达'
when   ch.width ='原装' and ch.invpinpai in ('东芝')   then '东芝'
when   ch.width ='原装' and ch.invpinpai in ('夏普')   then '夏普'
when   ch.width ='原装' and ch.invpinpai in ('理光')   then '理光'
when   ch.width ='原装' and ch.invpinpai in ('京瓷')   then '京瓷'
when   ch.width ='原装' and ch.invpinpai in ('理想','震旦','松下')   then '原装其他复印类'
when   ch.width ='原装'  then '原装其他打印类'
when   ch.width ='兼容' and ch.invpinpai like '%网络%' then '兼容网络版'
when   ch.width ='兼容' and ch.invpinpai = '懿品' then '懿品'
when   ch.width ='兼容' and ch.invpinpai = '懿品佳' then '懿品佳'
when   ch.width ='兼容' and ch.invpinpai = '懿品佳复印' then '懿品佳'
when   ch.width ='兼容' and ch.invpinpai like '%方格博士%' then '方格博士'
when   ch.width ='兼容' and ch.invpinpai like '%懿智通%' then '懿智通'
when   ch.width ='兼容' and ch.invpinpai like '%盈佳%' then '盈佳'
when   ch.width ='兼容' and ch.invpinpai like '%扬帆耐立%' then '扬帆耐立'
when   ch.width ='兼容' and ch.invpinpai like '%智通%' then '智通'
when   ch.width ='兼容' and ch.invpinpai like '%耐力%' then '扬帆耐立'
end 品牌分类,
ch.width as 大类,
ch.height as 小类,
p.vordercode as 订单号 ,
p.dr as 删除标志,
ck.storname as 库房,
p.forderstatus ,          
bb.cwarehouseid,
yy.cvendorbaseid 供应商id
from nc5x.po_invoice_b bb
join nc5x.po_invoice aa
  on bb.cinvoiceid = aa.cinvoiceid
join nc5x.bd_invbasdoc ch
  on bb.cbaseid = ch.pk_invbasdoc
join (select xx.custname,aa.cvendorbaseid,aa.cinvoiceid
        from nc5x.po_invoice aa
        join nc5x.bd_cubasdoc xx
          on aa.cvendorbaseid =xx.pk_cubasdoc )yy
  on yy.cinvoiceid = aa.cinvoiceid and aa.dr = 0
   left join nc5x.bd_stordoc ck
    on bb.cwarehouseid = ck.pk_stordoc
   left join nc5x.po_order p
   on p.corderid = bb.corderid
where (1=1)
and length(ch.invcode) >4
and aa.dinvoicedate >= '2022-07-01'
-- and bb.ninvoicenum >0 
) 
group by 供应商id,供应商名称





-- group by 存货主键,品牌分类,供应商名称,存货编码,存货名称,大类,品牌,品类,月份,单价,小类
