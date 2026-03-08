select
hl.vreceiptcode  as 单据号,
cu.pk_cubasdoc 客户主键,
cu.custname as 客户名称,
ch.invcode as 存货编码,
ch.invname as 存货名称,
ch.width as 大类,
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
ch.height as 小类,
js.nnewbalancenum as 数量,
js.nsummny/js.nnewbalancenum as 单价,
nvl(ch.最低限价,ch.批发售价) 最低限价,
ch.代理价,
ch.批发售价,
cu.deptname as 市场部,
cu.n_deptname as 部门,
yw.businame as 业务类型,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
cu.sf as 省,
cu.cs as 市,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利
from nc5x.so_squaredetail js
left join  nc5x.so_square zjs on js.csaleid = zjs.csaleid 
LEFT join ( 
select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,ch.unitweight,ch.unitvolume,cg.refsaleprice as 批发售价,cg.def5 as 代理价,cg.lowestprice as 最低限价
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc
         )ch
on js.cinventoryid = ch.pk_invmandoc
LEFT join nc5x.bd_busitype  yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust  cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc  us
on us.pk_psndoc= js.cemployeeid
left join nc5x.so_sale hl
on js.csourcebillid = hl.csaleid
where 
  length(ch.invcode) <> 4
  and js.dr=0
  and ch.width in ('原装','打印机','兼容')
  and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) >= to_char(sysdate-31,'yyyy-mm-dd')
  and js.blargessflag = 'N' 
  and js.nnewbalancenum > 0
  
