select 存货主键 ,
存货编码 ,
存货名称 ,
case when ma.大类 ='打印机' and ma.品牌 = '爱普生' then '爱普生打印机'
when ma.大类 ='打印机' and ma.品牌 like  '%佳能%' then '佳能打印机'
when ma.大类 ='打印机' and ma.品牌 = '奔图'then '奔图打印机'
when ma.大类 ='打印机' and ma.品牌 like '%华为%'  then '华为打印机'
when ma.大类 ='打印机' and ma.品牌 like '%惠普%' and ma.小类 = '行业' then '惠普打印机（行业）'
when ma.大类 ='打印机' and ma.品牌 like '%惠普%'  and ma.小类 = '渠道' then '惠普打印机（渠道）'
when ma.大类 ='打印机' then '其它品牌打印机'
when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '彩色' then '惠普彩鼓'
when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '硒鼓','配件') and ma.小类 = '黑色' then '惠普黑鼓'
when   ma.大类 ='原装' and ma.品牌 like '%惠普%'  and ma.品类 in ( '墨盒','墨水','介质')  then '惠普墨盒'
when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '粉仓','硒鼓')  then '三星'
when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '墨盒','墨水','介质')  then '佳能墨盒'
when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '硒鼓','粉仓','配件')  then '佳能硒鼓'
when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '硒鼓','粉仓')  then '施乐'
when   ma.大类 ='原装' and ma.品牌 = '奔图' then '奔图'
when   ma.大类 ='原装' and ma.品牌 = '兄弟' then '兄弟'
when   ma.大类 ='原装' and ma.品牌 = '华为' then '华为'
when   ma.大类 ='原装' and ma.品牌 = '立思辰' then '立思辰'
when   ma.大类 ='原装' and ma.品牌 = '富士通' then '富士通'
when   ma.大类 ='原装' and ma.品牌 = 'OKI' then 'OKI'
when   ma.大类 ='原装' and ma.品牌 = '联想' then '联想'
when   ma.大类 ='原装' and ma.品牌 = '爱普生' then '爱普生'
when   ma.大类 ='原装' and ma.品牌 = '利盟' then '利盟'
when   ma.大类 ='原装' and ma.品牌 like  '%佳能%' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '佳能复印类'
when   ma.大类 ='原装' and ma.品牌 = '施乐' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '施乐复印类'
when   ma.大类 ='原装' and ma.品牌 = '三星' and ma.品类 in ( '复印硒鼓','复印碳粉盒')  then '三星复印类'
when   ma.大类 ='原装' and ma.品牌 in ('柯尼卡美能达','德凡')   then '柯尼卡美能达'
when   ma.大类 ='原装' and ma.品牌 in ('东芝')   then '东芝'
when   ma.大类 ='原装' and ma.品牌 in ('夏普')   then '夏普'
when   ma.大类 ='原装' and ma.品牌 in ('理光')   then '理光'
when   ma.大类 ='原装' and ma.品牌 in ('京瓷')   then '京瓷'
when   ma.大类 ='原装' and ma.品牌 in ('理想','震旦','松下')   then '其他复印类'
when   ma.大类 ='原装'  then '其它打印类'
when   ma.大类 ='兼容' and ma.品牌 = '懿品' then '懿品'
when   ma.大类 ='兼容' and ma.品牌 = '懿品佳' then '懿品佳'
when   ma.大类 ='兼容' and ma.品牌 = '懿品佳复印' then '懿品佳'
when   ma.大类 ='兼容' and ma.品牌 like '方格博士%' then '方格博士'
when   ma.大类 ='兼容' and ma.品牌 like '懿智通%' then '懿智通'
when   ma.大类 ='兼容' and ma.品牌 like '盈佳%' then '盈佳'
when   ma.大类 ='兼容' and ma.品牌 like '扬帆耐立%' then '扬帆耐立'
when   ma.大类 ='兼容' and ma.品牌 like '耐力%' then '扬帆耐立'
when   ma.大类 ='兼容' and ma.品牌 like '智通%' then '智通'
 else '其他-异常'end  打印品牌,
大类 ,
品牌 ,
品类 ,
小类 ,
月份,
城市,
case when sum(销售数量)>=2000 then 'A+'
when sum(销售数量)>=1000 then 'A'
when sum(销售数量)>=200 then 'B'
when sum(销售数量)>=60 then 'C'
when sum(销售数量)>=20 then 'D'
ELSE 'E' end 存货等级,
sum(销售数量) 销售数量,            
sum(下单次数)下单次数,
sum(客户数)客户数,
sum(销售业务员数)销售业务员数,
sum(销售省份数) 销售省份数,
sum(销售流水) 销售流水,
sum(销售价税合计) 销售价税合计,
sum(结算数量)  结算数量,
sum(流水)流水,
sum(价税合计)价税合计,
sum(毛利) 毛利 
from (
select  
 nvl(a.存货主键,b.存货主键)存货主键 ,
nvl(a.存货编码,b.存货编码)存货编码 ,
nvl(a.存货名称,b.存货名称)存货名称 ,
nvl(a.大类,b.大类)大类 ,
nvl(a.品牌,b.品牌)品牌 ,
nvl(a.品类,b.品类)品类 ,
nvl(a.小类,b.小类)小类 ,
nvl(a.月份,b.月份)月份 ,
nvl(a.城市,b.城市)城市 ,
nvl(a.下单次数,0)下单次数,nvl(a.客户数,0)客户数,nvl(a.销售业务员数,0)销售业务员数,nvl(a.销售省份数,0)销售省份数,nvl(a.数量,0)销售数量,nvl(a.销售流水,0)销售流水,nvl(a.销售价税合计,0)销售价税合计,nvl(b.数量,0) as 结算数量,nvl(b.流水,0)流水,nvl(b.价税合计,0)价税合计,nvl(b.毛利,0) 毛利 
 from (
select 存货主键,ma.存货编码,ma.存货名称,ma.大类,品牌,品类,小类,月份,城市,
sum(数量) as 数量,
count(distinct 日期) as 下单次数,
count (distinct 主键 ) 客户数,
count (distinct 业务员 ) 销售业务员数,
count (distinct 省 ) 销售省份数,
sum(流水) 销售流水,sum(价税合计) 销售价税合计
from  
( select 
ii.vreceiptcode,
ii.creceiptcustomerid as 主键,
ib.pk_invbasdoc 存货主键,
m.vreceiptcode  as 外部单号,
ii.VRECEIPTCODE 发票号,
ii.dbilldate as 日期,
substr(ii.dbilldate,1,7) as 月份,
cu.deptname as 市场部,
cu.n_deptname as 部门,
cu.psnname as 业务员,
us.psnname ,
cu.pk_cubasdoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
cu.sf as 省 ,
cu.cs as 市 ,
II.VDEF7 AS 货运公司,
ii.dr 删除标志 ,
yw.businame as 业务类型,
ii.vnote as 备注,
ib.nnumber as 数量,
ib.nsummny as 价税合计,
ib.noriginalcurmny as 流水,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.blargessflag  as 是否赠品,
translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1 ,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
ck.storname as 库房,
  case when ck.storname in('1号库',
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
when ck.storname in('成 都门市',
'成都本部',
'成 都本部残品库',
'成 都天猫库',
'成 都99库') then '成都'
when ck.storname in('哈尔滨本部',
'哈 尔滨本部残品库') then '哈尔滨'
when ck.storname in('南京本部',
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
when ck.storname in('沈 阳数码',
'沈阳本部',
'沈 阳本部残品库',
'沈 阳99库',
'维修站-沈阳检测库',
'沈 阳数码残品库') then '沈阳'
when ck.storname in('西安本部',
'西安科贸',
'西 安本部残品库',
'西 安99库') then '西安'
when ck.storname in('中山仓',
'中山99库') then '中山'
when ck.storname in('重庆本部',
'重 庆本部残品库') then '重庆' end 城市,
m.vdef20 as 收货地址,
m.vdef8 as 服务商,
case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcustomerid = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
     left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.bd_psndoc  us
on us.pk_psndoc= ii.cemployeeid

where (1=1) and length(ib.invcode) > 4 
and  ii.dr=0  
and ib.width  in ('兼容','原装','打印机')
and ii.dbilldate >='2021-01-01'
--and ii.dbilldate >=to_char(trunc(sysdate, 'mm'),'yyyy-mm-dd')
 -- and ck.storname <> '首创虚拟库'
 )ma  group by 存货主键,ma.存货编码,ma.存货名称,ma.大类,品牌,品类,小类,月份,城市) a 
 full join 
 (select 存货主键,ma.存货编码,ma.存货名称,ma.大类,品牌,品类,小类,月份,城市
,sum(数量) 数量 ,sum(毛利) 毛利 ,sum(流水)流水,sum(价税合计)价税合计
from (
select 
  case when ck.storname in('1号库',
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
when ck.storname in('成 都门市',
'成都本部',
'成 都本部残品库',
'成 都天猫库',
'成 都99库') then '成都'
when ck.storname in('哈尔滨本部',
'哈 尔滨本部残品库') then '哈尔滨'
when ck.storname in('南京本部',
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
when ck.storname in('沈 阳数码',
'沈阳本部',
'沈 阳本部残品库',
'沈 阳99库',
'维修站-沈阳检测库',
'沈 阳数码残品库') then '沈阳'
when ck.storname in('西安本部',
'西安科贸',
'西 安本部残品库',
'西 安99库') then '西安'
when ck.storname in('中山仓',
'中山99库') then '中山'
when ck.storname in('重庆本部',
'重 庆本部残品库') then '重庆' else '北京' end 城市,
js.ccustomerid 主键,
cu.pk_cubasdoc 客户主键,
cu.custcode as 客户编码,
cu.custname as 客户名称,
cg.pk_invbasdoc as 存货主键,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
yw.businame as 业务类型,
js.vdef11 as 业务属性,
case when js.blargessflag = 'Y' then 0 else js.nsummny end  as 本币价税合计 ,
js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
(CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end AS 流水,
case when js.blargessflag = 'Y' then 0 else (ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)) end-js.ncostmny AS 毛利,
js.ncostmny as 成本,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
(case when js.dapprovedate is null then substr(js.dmakedate,1,7) else substr(js.dapprovedate,1,7)  end )as 月份,
cu.sf as 省,
cu.cs as 市
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc,cg.pk_invbasdoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc )cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype  yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust  cu
on js.ccustomerid = cu.pk_cumandoc
left join nc5x.bd_psndoc  us
on us.pk_psndoc= js.cemployeeid
     left join nc5x.bd_stordoc ck
    on js.cwarehouseid = ck.pk_stordoc
where 
  length(cg.invcode) <> 4
  and js.dr=0
  and cg.width in ('兼容','原装','打印机')
  and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )>=  '2021-01-01'  
  -- and js.dapprovedate is  not null 
  ) ma group by 存货主键,ma.存货编码,ma.存货名称,ma.大类,品牌,品类,小类,月份,城市) b 
  on a.存货主键=b.存货主键 and a.月份 = b.月份 and  a.城市= b.城市 
  )ma  group by
存货主键,
存货编码,
存货名称,
大类,
品牌,
品类,
小类,
月份,
城市
order by 存货编码,月份


      



