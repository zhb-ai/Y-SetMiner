select * from 
(select 
aa.pk_invbasdoc as 主键,
aa.invcode as 存货编码,
aa.invname  as 存货名称,
aa.def10 as 供应商,
aa.def2 as 装箱数,
case when aa.def8 not like '%不备货%' then '不备货' else '备货' end 是否备货,
aa.invpinpai   as 品牌 ,
aa.width    as 大类 ,
aa.length    as 品类 ,
aa.height   as 小类 
 from nc5x.bd_invbasdoc aa 
join nc5x.bd_invmandoc bb 
on aa.pk_invbasdoc = bb.pk_invbasdoc  
where   
 bb.sealflag  ='N'
)zz left join 
(select 存货主键,
sum(数量)历史总销量,
sum(case when 客户分 ='北京' then 数量 else 0 end ) 大库历史销量,
sum(case when 客户分 ='成都' then 数量 else 0 end ) 成都历史销量,
sum(case when 客户分 ='重庆' then 数量 else 0 end ) 重庆历史销量,
sum(case when 客户分 ='沈阳' then 数量 else 0 end ) 沈阳历史销量,
sum(case when 客户分 ='哈尔滨' then 数量 else 0 end )哈尔滨历史销量,
sum(case when 客户分 ='西安' then 数量 else 0 end ) 西安历史销量,
sum(case when 客户分 ='南京' then 数量 else 0 end ) 南京历史销量,
max(case when 客户分 ='北京' then 最大数量 else 0 end) 最大值,
max(case when 客户分 ='成都' then 最大数量 else 0 end) 成都最大值,
max(case when 客户分 ='重庆' then 最大数量 else 0 end) 重庆最大值,
max(case when 客户分 ='沈阳' then 最大数量 else 0 end) 沈阳最大值,
max(case when 客户分 ='哈尔滨' then 最大数量 else 0 end)哈尔滨最大值,
max(case when 客户分 ='西安' then 最大数量 else 0 end) 西安最大值,
max(case when 客户分 ='南京' then 最大数量 else 0 end) 南京最大值,
sum(case when 客户分 ='北京' then 订单量 else 0 end) 订单数量,
sum(case when 客户分 ='成都' then 订单量 else 0 end) 成都订单,
sum(case when 客户分 ='重庆' then 订单量 else 0 end) 重庆订单,
sum(case when 客户分 ='沈阳' then 订单量 else 0 end) 沈阳订单,
sum(case when 客户分 ='哈尔滨' then 订单量 else 0 end)哈尔滨订单,
sum(case when 客户分 ='西安' then 订单量 else 0 end) 西安订单,
sum(case when 客户分 ='南京' then 订单量 else 0 end) 南京订单  
from 
(
select 存货主键 ,客户分 ,sum(数量) 数量,max(数量) 最大数量,count(distinct 订单号) 订单量 from (
select  rownum,ma.* ,case when ma.客户分布 in ( '甘肃省','宁夏回族自治区','青海省','陕西省', '新疆维吾尔自治区') then '西安'
  when ma.客户分布 in ( '安徽省','广西壮族自治区','湖北省','湖南省', '江苏省', '上海市', '浙江省','江西省', '福建省', '广东省','海南省','台湾省', '香港特别行政区', '澳门特别行政区')then '南京' 
  when ma.客户分布 in ( '内蒙古自治区','河北省','河南省','北京市', '山东省','山西省', '天津市') then '北京'
  when ma.客户分布 in ( '贵州省','四川省','西藏自治区','云南省', '重庆市') then '成都'
  when ma.客户分布 in ( '黑龙江省') then '哈尔滨'
  when ma.客户分布 in ( '吉林省','辽宁省') then '沈阳'
  end as  客户分  from ( select ii.csaleid as  主键 ,
cu.deptname as  市场部,
cu.n_deptname as  部门,
cu.psnname as  业务员,
cu.pk_cumandoc  as 客户主键,
case when ii.vnote like '%\%' then '0' else ii.vnote  end as 备注,
m.vreceiptcode 订单号,
ib.nnumber as 数量,
substr(to_char(to_date(ii.dbilldate,'yyyy-mm-dd') ,'yyyy-mm-dd'),1,10)as 日期,
yw.businame as 业务类型,
ib.cinvbasdocid as 存货主键,
ck.storname as 出库仓库,
ii.VRECEIPTCODE 发票号,
ii.dr 删除标志,
 case when substr(m.vdef20,0,3) like '%北京%' then '北京市'
      when substr(m.vdef20,0,3) like '%天津%' then '天津市'
      when substr(m.vdef20,0,3) like '%河北%' then '河北省'
      when substr(m.vdef20,0,3) like '%山西%' then '山西省'
      when substr(m.vdef20,0,3) like '%内蒙%'and (m.vdef20 like '%通辽%'or m.vdef20 like '%呼伦贝尔%'or m.vdef20 like '%兴安盟%') then '辽宁省'
      when substr(m.vdef20,0,3) like '%内蒙%' then '内蒙古自治区'
      when substr(m.vdef20,0,3) like '%辽宁%' then '辽宁省'
      when substr(m.vdef20,0,3) like '%吉林%' then '吉林省'
      when substr(m.vdef20,0,3) like '%黑龙江%' then '黑龙江省'
      when substr(m.vdef20,0,3) like '%上海%' then '上海市'
      when substr(m.vdef20,0,3) like '%江苏%' then '江苏省'
      when substr(m.vdef20,0,3) like '%浙江%' then '浙江省'
      when substr(m.vdef20,0,3) like '%安徽%' then '安徽省'
      when substr(m.vdef20,0,3) like '%福建%' then '福建省'
      when substr(m.vdef20,0,3) like '%江西%' then '江西省'
      when substr(m.vdef20,0,3) like '%山东%' then '山东省'
      when substr(m.vdef20,0,3) like '%河南%' then '河南省'
      when substr(m.vdef20,0,3) like '%湖北%' then '湖北省'
      when substr(m.vdef20,0,3) like '%湖南%' then '湖南省'
      when substr(m.vdef20,0,3) like '%广东%' then '广东省'
      when substr(m.vdef20,0,3) like '%广西%' then '广西壮族自治区'
      when substr(m.vdef20,0,3) like '%海南%' then '海南省'
      when substr(m.vdef20,0,3) like '%重庆%' then '重庆市'
      when substr(m.vdef20,0,3) like '%四川%' then '四川省'
      when substr(m.vdef20,0,3) like '%贵州%' then '贵州省'
      when substr(m.vdef20,0,3) like '%云南%' then '云南省'
      when substr(m.vdef20,0,3) like '%西藏%' then '西藏自治区'
      when substr(m.vdef20,0,3) like '%陕西%' then '陕西省'
      when substr(m.vdef20,0,3) like '%甘肃%' then '甘肃省'
      when substr(m.vdef20,0,3) like '%青海%' then '青海省'
      when substr(m.vdef20,0,3) like '%宁夏%' then '宁夏回族自治区'
      when substr(m.vdef20,0,3) like '%新疆%' then '新疆维吾尔自治区'
      when substr(m.vdef20,0,3) like '%台湾%' then '台湾省'
      when substr(m.vdef20,0,3) like '%香港%' then '香港特别行政区'
      when substr(m.vdef20,0,3) like '%澳门%' then '澳门特别行政区'
      when cu.sf = '北京' then '北京市'
      when cu.sf = '天津' then '天津市'
      when cu.sf = '河北省' then '河北省'
      when cu.sf = '山西省' then '山西省'
      when cu.sf = '内蒙古自治区' then '内蒙古自治区'
      when cu.sf = '辽宁省' then '辽宁省'
      when cu.sf = '吉林省' then '吉林省'
      when cu.sf = '黑龙江省' then '黑龙江省'
      when cu.sf = '上海' then '上海市'
      when cu.sf = '江苏省' then '江苏省'
      when cu.sf = '浙江省' then '浙江省'
      when cu.sf = '安徽省' then '安徽省'
      when cu.sf = '福建省' then '福建省'
      when cu.sf = '江西省' then '江西省'
      when cu.sf = '山东省' then '山东省'
      when cu.sf = '河南省' then '河南省'
      when cu.sf = '湖北省' then '湖北省'
      when cu.sf = '湖南省' then '湖南省'
      when cu.sf = '广东省' then '广东省'
      when cu.sf = '广西壮族自治区' then '广西壮族自治区'
      when cu.sf = '海南省' then '海南省'
      when cu.sf = '重庆' then '重庆市'
      when cu.sf = '四川省' then '四川省'
      when cu.sf = '贵州省' then '贵州省'
      when cu.sf = '云南省' then '云南省'
      when cu.sf = '西藏自治区' then '西藏自治区'
      when cu.sf = '陕西省' then '陕西省'
      when cu.sf = '甘肃省' then '甘肃省'
      when cu.sf = '青海省' then '青海省'
      when cu.sf = '宁夏回族自治区' then '宁夏回族自治区'
      when cu.sf = '新疆维吾尔自治区' then '新疆维吾尔自治区'
      when cu.sf like '%台湾省%' then '台湾省'
      when cu.sf like '%香港%' then '香港特别行政区'
      when cu.sf like '%澳门%' then '澳门特别行政区'
      else null end 客户分布
from nc5x.so_saleinvoice ii
join (select ib.cinvbasdocid, ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode
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
where 
ii.dbilldate >= to_char(sysdate - 91,'yyyy-mm-dd')   
and ii.dr=0 
and ib.width  in ('兼容','原装','打印机') and ck.storname not in ('首创虚拟库') )ma) group by 存货主键,客户分) group by 存货主键 )a 
on zz.主键 = a.存货主键
left join 
(select 存货主键 ,
sum(数量)总销量,
sum(case when 客户分 ='北京' then 数量 else 0 end ) 大库销量,
sum(case when 客户分 ='成都' then 数量 else 0 end ) 成都销量,
sum(case when 客户分 ='重庆' then 数量 else 0 end ) 重庆销量,
sum(case when 客户分 ='沈阳' then 数量 else 0 end ) 沈阳销量,
sum(case when 客户分 ='哈尔滨' then 数量 else 0 end )哈尔滨销量,
sum(case when 客户分 ='西安' then 数量 else 0 end ) 西安销量,
sum(case when 客户分 ='南京' then 数量 else 0 end ) 南京销量 
from 
(
select 存货主键 ,客户分 ,sum(数量) 数量,max(数量) 最大数量,count(distinct 订单号) 订单量 from (
select  rownum,ma.* ,
case when ma.客户分布 in ( '甘肃省','宁夏回族自治区','青海省','陕西省', '新疆维吾尔自治区') then '西安'
  when ma.客户分布 in ( '安徽省','广西壮族自治区','湖北省','湖南省', '江苏省', '上海市', '浙江省','江西省', '福建省', '广东省','海南省','台湾省', '香港特别行政区', '澳门特别行政区')then '南京' 
  when ma.客户分布 in ( '内蒙古自治区','河北省','河南省','北京市', '山东省','山西省', '天津市') then '北京'
  when ma.客户分布 in ( '贵州省','四川省','西藏自治区','云南省', '重庆市') then '成都'
  when ma.客户分布 in ( '黑龙江省') then '哈尔滨'
  when ma.客户分布 in ( '吉林省','辽宁省') then '沈阳'
  end as  客户分
  from ( select ii.csaleid as  主键 ,
cu.deptname as  市场部,
cu.n_deptname as  部门,
cu.psnname as  业务员,
cu.pk_cumandoc  as 客户主键,
case when ii.vnote like '%\%' then '0' else ii.vnote  end as 备注,
m.vreceiptcode 订单号,
ib.nnumber as 数量,
substr(to_char(to_date(ii.dbilldate,'yyyy-mm-dd') ,'yyyy-mm-dd'),1,10)as 日期,
yw.businame as 业务类型,
ib.cinvbasdocid as 存货主键,
ck.storname as 出库仓库,
ii.VRECEIPTCODE 发票号,
ii.dr 删除标志,
 case when substr(m.vdef20,0,3) like '%北京%' then '北京市'
      when substr(m.vdef20,0,3) like '%天津%' then '天津市'
      when substr(m.vdef20,0,3) like '%河北%' then '河北省'
      when substr(m.vdef20,0,3) like '%山西%' then '山西省'
      when substr(m.vdef20,0,3) like '%内蒙%'and (m.vdef20 like '%通辽%'or m.vdef20 like '%呼伦贝尔%'or m.vdef20 like '%兴安盟%') then '辽宁省'
      when substr(m.vdef20,0,3) like '%内蒙%' then '内蒙古自治区'
      when substr(m.vdef20,0,3) like '%辽宁%' then '辽宁省'
      when substr(m.vdef20,0,3) like '%吉林%' then '吉林省'
      when substr(m.vdef20,0,3) like '%黑龙江%' then '黑龙江省'
      when substr(m.vdef20,0,3) like '%上海%' then '上海市'
      when substr(m.vdef20,0,3) like '%江苏%' then '江苏省'
      when substr(m.vdef20,0,3) like '%浙江%' then '浙江省'
      when substr(m.vdef20,0,3) like '%安徽%' then '安徽省'
      when substr(m.vdef20,0,3) like '%福建%' then '福建省'
      when substr(m.vdef20,0,3) like '%江西%' then '江西省'
      when substr(m.vdef20,0,3) like '%山东%' then '山东省'
      when substr(m.vdef20,0,3) like '%河南%' then '河南省'
      when substr(m.vdef20,0,3) like '%湖北%' then '湖北省'
      when substr(m.vdef20,0,3) like '%湖南%' then '湖南省'
      when substr(m.vdef20,0,3) like '%广东%' then '广东省'
      when substr(m.vdef20,0,3) like '%广西%' then '广西壮族自治区'
      when substr(m.vdef20,0,3) like '%海南%' then '海南省'
      when substr(m.vdef20,0,3) like '%重庆%' then '重庆市'
      when substr(m.vdef20,0,3) like '%四川%' then '四川省'
      when substr(m.vdef20,0,3) like '%贵州%' then '贵州省'
      when substr(m.vdef20,0,3) like '%云南%' then '云南省'
      when substr(m.vdef20,0,3) like '%西藏%' then '西藏自治区'
      when substr(m.vdef20,0,3) like '%陕西%' then '陕西省'
      when substr(m.vdef20,0,3) like '%甘肃%' then '甘肃省'
      when substr(m.vdef20,0,3) like '%青海%' then '青海省'
      when substr(m.vdef20,0,3) like '%宁夏%' then '宁夏回族自治区'
      when substr(m.vdef20,0,3) like '%新疆%' then '新疆维吾尔自治区'
      when substr(m.vdef20,0,3) like '%台湾%' then '台湾省'
      when substr(m.vdef20,0,3) like '%香港%' then '香港特别行政区'
      when substr(m.vdef20,0,3) like '%澳门%' then '澳门特别行政区'
      when cu.sf = '北京' then '北京市'
      when cu.sf = '天津' then '天津市'
      when cu.sf = '河北省' then '河北省'
      when cu.sf = '山西省' then '山西省'
      when cu.sf = '内蒙古自治区' then '内蒙古自治区'
      when cu.sf = '辽宁省' then '辽宁省'
      when cu.sf = '吉林省' then '吉林省'
      when cu.sf = '黑龙江省' then '黑龙江省'
      when cu.sf = '上海' then '上海市'
      when cu.sf = '江苏省' then '江苏省'
      when cu.sf = '浙江省' then '浙江省'
      when cu.sf = '安徽省' then '安徽省'
      when cu.sf = '福建省' then '福建省'
      when cu.sf = '江西省' then '江西省'
      when cu.sf = '山东省' then '山东省'
      when cu.sf = '河南省' then '河南省'
      when cu.sf = '湖北省' then '湖北省'
      when cu.sf = '湖南省' then '湖南省'
      when cu.sf = '广东省' then '广东省'
      when cu.sf = '广西壮族自治区' then '广西壮族自治区'
      when cu.sf = '海南省' then '海南省'
      when cu.sf = '重庆' then '重庆市'
      when cu.sf = '四川省' then '四川省'
      when cu.sf = '贵州省' then '贵州省'
      when cu.sf = '云南省' then '云南省'
      when cu.sf = '西藏自治区' then '西藏自治区'
      when cu.sf = '陕西省' then '陕西省'
      when cu.sf = '甘肃省' then '甘肃省'
      when cu.sf = '青海省' then '青海省'
      when cu.sf = '宁夏回族自治区' then '宁夏回族自治区'
      when cu.sf = '新疆维吾尔自治区' then '新疆维吾尔自治区'
      when cu.sf like '%台湾省%' then '台湾省'
      when cu.sf like '%香港%' then '香港特别行政区'
      when cu.sf like '%澳门%' then '澳门特别行政区'
      else null end 客户分布
from nc5x.so_saleinvoice ii
join (select ib.cinvbasdocid, ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode
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
where 
ii.dbilldate >= to_char(sysdate - 31,'yyyy-mm-dd')   
and ii.dr=0 
and ib.width  in ('兼容','原装','打印机') and ck.storname not in ('首创虚拟库') )ma) group by 存货主键,客户分) group by 存货主键) b on a.存货主键=b.存货主键 
left join 
(select
bb.pk_invbasdoc  主键,
SUM(dd.nonhandnum)   结存数量 ,
sum(case when storcode in ('001','005','013','043','084','099','065','086','070','080','067','085') then dd.nonhandnum else 0 end) 大库库存,
sum(case when storcode in ('051','052') then dd.nonhandnum else 0 end) 成都库存,
sum(case when storcode in ('059','058') then dd.nonhandnum else 0 end) 重庆库存,
sum(case when storcode in ('017','019','346','01701') then dd.nonhandnum else 0 end) 沈阳库存,
sum(case when storcode in ('020') then dd.nonhandnum else 0 end) 哈尔滨库存,
sum(case when storcode in ('056','057') then dd.nonhandnum else 0 end) 西安库存,
sum(case when storcode in ('022','069','02202','073','074','078','068','087') then dd.nonhandnum else 0 end) 南京库存,
sum(case when storcode  in ('076') then dd.nonhandnum else 0 end) 中山库存
from nc5x.bd_invbasdoc bb
join (select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc,cc.storname,cc.storcode
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc) dd
on dd.cinvbasid = bb.pk_invbasdoc
where dd.nonhandnum<>0 and storcode in ('001','005','013','043','084','099','065','086','070','080','067','085','022','069','02202','073','074','078','068','087','017','019','346','01701','051','052','058','056','057','020','076','145')
GROUP BY bb.pk_invbasdoc order by 1 asc) mm
on zz.主键 = mm.主键
left join 
(select cinvbasid 主键 ,
sum(case when storcode in ('001','005','013','043','084','099','065','086','070','080','067','085') then nshouldinnum else 0 end) 北京在途,
sum(case when storcode in ('051','052') then nshouldinnum else 0 end) 成都在途,
sum(case when storcode in ('059','058') then nshouldinnum else 0 end) 重庆在途,
sum(case when storcode in ('017','019','346','01701') then nshouldinnum else 0 end) 沈阳在途 ,
sum(case when storcode in ('020') then nshouldinnum else 0 end) 哈尔滨在途 ,
sum(case when storcode in ('056','057')  then nshouldinnum else 0 end) 西安在途 ,
sum(case when storcode in ('022','069','02202','073','074','078','068','087') then nshouldinnum else 0 end) 南京在途
 FROM
(select ck.storname,ck.storcode ,c.cinvbasid,iv.invname,c.nshouldinnum from (
select h.CGENERALHID,h.CWAREHOUSEID,b.cinvbasid,b.nshouldinnum from nc5x.ic_general_h  h 
join nc5x.ic_general_b b  on  h.CGENERALHID=b.CGENERALHID 
where h.CBILLTYPECODE ='4E' AND h.DACCOUNTDATE IS NULL AND h.TMAKETIME > to_char(sysdate-31,'yyyy-mm-dd') ||' 00:00:00' and h.dr=0 and b.dr=0
) c
 LEFT join nc5x.bd_stordoc ck on c.cwarehouseid = ck.pk_stordoc
 LEFT join nc5x.bd_invbasdoc iv on c.cinvbasid= iv.pk_invbasdoc ) 
WHERE storcode in ('001','005','013','043','084','099','065','086','070','080','067','085','022','069','02202','073','074','078','068','087','017','019','346','01701','051','052','058','056','057','020','076','145')
 GROUP BY cinvbasid order by 1 asc 
) db on zz.主键 = db.主键
left join 
(select a.存货主键,
a.第一季销量,
a.第四季销量,
a.总销量,
case
when 第一季销量 >100 and  增长率>=1 then '翻倍增长'
when 第一季销量 >100  and  增长率>=0.5 then '迅速增长'
when 增长率 >= 0.2 then '增长'
when 增长率 >= -0.1 then '正常'
when 总销量 >400  and  增长率 >= -0.5 then '下降'
when 总销量 >400  and 增长率 >= -1 then '迅速下降'
else '' end 增长判断
from (
select  存货主键,
存货编码, 存货名称,大类,品牌,品类,小类,
sum(第一季销量)第一季销量,
sum(第二季销量)第二季销量,
sum(第三季销量)第三季销量,
sum(第四季销量)第四季销量,
sum(数量) 总销量,
case 
when sum(第一季销量)<= 0 and sum(第四季销量)>=100 then 1
when sum(第四季销量)<= 0 and sum(第一季销量)>=0 then -1
when sum(第一季销量)>=100 or sum(第四季销量)>= 100 then sum(第四季销量)/sum(第一季销量)-1 else 0 end 增长率,
case when sum(第四季销量)>= 100 then sum(第四季销量)/sum(数量) else 0 end 近期销量占比,
case  when sum(第一季销量)+sum(第二季销量) <= 0 and sum(第三季销量)+sum(第四季销量)> 200 then 1
when sum(第一季销量)+sum(第二季销量) >= 200 or sum(第三季销量)+sum(第四季销量) > 200 then   (sum(第三季销量)+sum(第四季销量))/  (sum(第一季销量)+sum(第二季销量)) -1 else 0 end  半年增长率
from  
( select 
ib.pk_invbasdoc 存货主键,
ii.dbilldate as 日期,
case when  ii.dbilldate between to_char(sysdate-360,'yyyy-mm-dd') and to_char(sysdate-271,'yyyy-mm-dd') then ib.nnumber else 0 end 第一季销量,
case when  ii.dbilldate between to_char(sysdate-270,'yyyy-mm-dd') and to_char(sysdate-181,'yyyy-mm-dd') then  ib.nnumber else 0 end 第二季销量,
case when  ii.dbilldate between to_char(sysdate-180,'yyyy-mm-dd') and to_char(sysdate-91,'yyyy-mm-dd') then   ib.nnumber else 0 end 第三季销量,
case when  ii.dbilldate between to_char(sysdate-90,'yyyy-mm-dd') and to_char(sysdate,'yyyy-mm-dd') then  ib.nnumber else 0 end 第四季销量,
ib.nnumber as 数量,
ib.invcode as 存货编码,
ib.invname as 存货名称,
ib.length as 品类,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌
from nc5x.so_saleinvoice ii
left  join (
select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny,
ch.unitvolume,
ch.unitweight
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc 
) ib
on ib.csaleid = ii.csaleid
where ii.dr = 0
and ib.width in ('兼容') and length(ib.invcode) > 4 
and ii.dbilldate >= to_char(sysdate-360,'yyyy-mm-dd')
) ma 
group by 存货主键, 存货编码, 存货名称,大类,品牌,品类,小类 )a )gm  on gm.存货主键 = zz.主键


