select * from (
select nvl(a.品类,b.品类) 品类,nvl(a.大类,b.大类) 大类, nvl(a.品牌分类,b.品牌分类) 品牌分类,nvl(a.日期,b.日期) 日期,substr(nvl(a.日期,b.日期),1,7) 月份 ,nvl(a.库房,b.库房) 库房,nvl(a.城市,b.城市)城市 ,
nvl(a.品牌,b.品牌)品牌, nvl(a.小类 ,b.小类) 小类,
a.库存数量,a.库存金额,b.价税合计 from 
(select 
大类,品牌分类,日期,品类, 库房,城市,小类,品牌,
sum(js.nonhandnum) 库存数量,
sum(js.jcprice*js.nonhandnum)库存金额 from 
(select  
ch.width as 大类,
ch.length as 品类,
ch.height as 小类,
ch.invpinpai as 品牌,
js.nonhandnum ,
js.jcprice ,
dd.storname as 库房,
case when dd.storname in('1号库',
'京东云仓北京一号库',
'京东pop仁和-FBP-协同仓-1号库',
'科贸3A003',
'盛购2-650',
'天 猫残品库',
'天猫库',
'京东pop仁和-FBP-北京仓',
'京东pop仁和-SOP-北京仓',
'科贸3H006',
'首创库',
'维修站-北京原装耗材检测库',
'维修站-北京打印机检测库',
'99库',
'维修站-成品库',
'工厂直发库',
'京东虚拟库',
'盛 购2-650残品库',
'1 号库残品库',
'科 贸3A003残品库',
'维修站-兼容残品库',
'到货测试库',
'首创虚拟库',
'虚拟库-打合同临时用') then '北京'
when dd.storname in('成 都门市',
'成都本部',
'成 都本部残品库',
'成 都天猫库',
'成 都99库') then '成都'
when dd.storname in('哈尔滨本部',
'哈 尔滨本部残品库') then '哈尔滨'
when dd.storname in('南京本部',
'京东pop仁和-SOP-上海仓',
'京东pop仁和-SOP-广州仓',
'京东pop仁和-SOP-武汉仓',
'南 京天猫库',
'京东pop仁和-FBP-广州仓',
'京东pop仁和-FBP-上海仓',
'京东pop仁和-FBP-武汉仓',
'维修站-南京检测库',
'南 京99库',
'南 京本部残品库') then '南京'
when dd.storname in('沈 阳数码',
'沈阳本部',
'沈 阳本部残品库',
'沈 阳99库',
'维修站-沈阳检测库',
'沈 阳数码残品库') then '沈阳'
when dd.storname in('西安本部',
'西安科贸',
'西 安本部残品库',
'西 安99库') then '西安'
when dd.storname in('中山仓',
'中山99库') then '中山'
when dd.storname in('重庆本部',
'重 庆本部残品库') then '重庆' end 城市,


substr(to_char(js.dbdate,'99999999'),2,4)||'-'||substr(to_char(js.dbdate,'99999999'),6,2)||'-'||substr(to_char(js.dbdate,'99999999'),8,2) 日期,
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
js.dbdate
from nc5x.story_num js
join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc)ch
on js.cinventoryid = ch.pk_invmandoc
join nc5x.bd_stordoc dd
on dd.pk_stordoc=js.cwarehouseid
where js.nonhandnum >0 and js.dbdate >= '20220101' and  length(ch.invcode) > 4 
and ch.width  in ('兼容','原装','打印机')
) js
group by 大类,品牌分类,日期,品类, 库房,小类,品牌,城市
order by 日期 desc )  a
full join 
(select
  ii.dbilldate as 日期,
  ib.width as 大类,
  ib.length as 品类,
  ib.height as 小类,
ib.invpinpai as 品牌,
  品牌分类,
  dd.storname as 库房,
  case when dd.storname in('1号库',
'京东云仓北京一号库',
'京东pop仁和-FBP-协同仓-1号库',
'科贸3A003',
'盛购2-650',
'天 猫残品库',
'天猫库',
'京东pop仁和-FBP-北京仓',
'京东pop仁和-SOP-北京仓',
'科贸3H006',
'首创库',
'维修站-北京原装耗材检测库',
'维修站-北京打印机检测库',
'99库',
'维修站-成品库',
'工厂直发库',
'京东虚拟库',
'盛 购2-650残品库',
'1 号库残品库',
'科 贸3A003残品库',
'维修站-兼容残品库',
'到货测试库',
'首创虚拟库',
'虚拟库-打合同临时用') then '北京'
when dd.storname in('成 都门市',
'成都本部',
'成 都本部残品库',
'成 都天猫库',
'成 都99库') then '成都'
when dd.storname in('哈尔滨本部',
'哈 尔滨本部残品库') then '哈尔滨'
when dd.storname in('南京本部',
'京东pop仁和-SOP-上海仓',
'京东pop仁和-SOP-广州仓',
'京东pop仁和-SOP-武汉仓',
'南 京天猫库',
'京东pop仁和-FBP-广州仓',
'京东pop仁和-FBP-上海仓',
'京东pop仁和-FBP-武汉仓',
'维修站-南京检测库',
'南 京99库',
'南 京本部残品库') then '南京'
when dd.storname in('沈 阳数码',
'沈阳本部',
'沈 阳本部残品库',
'沈 阳99库',
'维修站-沈阳检测库',
'沈 阳数码残品库') then '沈阳'
when dd.storname in('西安本部',
'西安科贸',
'西 安本部残品库',
'西 安99库') then '西安'
when dd.storname in('中山仓',
'中山99库') then '中山'
when dd.storname in('重庆本部',
'重 庆本部残品库') then '重庆' end 城市,
  sum(ib.nsummny) as 价税合计
from nc5x.so_saleinvoice ii
join (
select
ib.csaleid,
ib.nsummny,
ch.invcode,
ch.length ,
ch.width ,
ch.height ,
ch.invpinpai ,
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
  end 品牌分类
from nc5x.so_saleinvoice_b ib
  join nc5x.bd_invbasdoc ch
  on ib.cinvbasdocid = ch.pk_invbasdoc
  where length(ch.invcode) > 4 
) ib
on ib.csaleid = ii.csaleid
left join nc5x.bd_stordoc dd
on ii.cwarehouseid = dd.pk_stordoc
where ii.dbilldate >='2022-01-01'
and ii.dr=0 
and ib.width  in ('兼容','原装','打印机')
group by ii.dbilldate,ib.width,品牌分类,ib.length , dd.storname,  ib.height ,
ib.invpinpai 
order by ii.dbilldate desc) b on a.日期 = b.日期 and a.品牌分类 = b.品牌分类  and  a.品类=b.品类 and a.库房 = b.库房 and a.品牌 = b.品牌 and a.小类 = b.小类 and a.城市=b.城市 )
-- where 价税合计 is not null and 库存数量 is null 
