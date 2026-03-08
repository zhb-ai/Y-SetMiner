select
aa.pk_invbasdoc  主键,
aa.invcode as 存货编码,
aa.invname  as 存货名称,
aa.invpinpai   as 品牌 ,
aa.width    as 大类 ,
aa.length    as 品类 ,
aa.height   as 小类 , 
dd.storname as 库房,
aa.def19  as 税票型号,
substr(aa.def19,1,INSTR(aa.def19,'-',-1,1)-1) as 型号,
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
SUM(dd.nonhandnum)   结存数量 
from nc5x.bd_invbasdoc aa

join (select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc , cc.storname
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc) dd
on dd.cinvbasid = aa.pk_invbasdoc
where 
dd.nonhandnum<>0 
and 
dd.storname in ('天猫库',
'盛购2-650',
'科贸3H006',
'科贸3A003',
'京东云仓北京一号库',
'99库',
'1号库',
'成都本部',
'成 都天猫库',
'成 都门市',
'哈尔滨本部',
'南京本部',
'南 京天猫库',
'南 京99库',
'沈阳本部',
'沈 阳数码',
'沈 阳99库',
'西安科贸',
'西安本部',
'中山仓',
'中山99库',
'重庆本部'
 ) and length(aa.invcode)>4 and aa.width = '兼容' and aa.length in ('硒鼓','复印硒鼓','复印碳粉盒') and aa.height = '彩色'   
GROUP BY 
aa.pk_invbasdoc,
aa.invcode ,
aa.invname ,
aa.invpinpai ,
aa.width  ,
aa.length ,
aa.height,
dd.storname,
aa.def19    
order by 1 asc


