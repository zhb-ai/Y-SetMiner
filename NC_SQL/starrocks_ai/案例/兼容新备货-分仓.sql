
select  存货编码,存货名称,分仓,仓库编码
,sum(销量) 九十天分仓销量,count(distinct 客户主键)九十天分仓客户数, max(销量)九十天分仓最大单笔数量
,sum(三十天分仓销量) 三十天分仓销量,count(distinct 三十天客户主键)三十天分仓客户数, max(三十天分仓销量)三十天最大单笔数量
from （
select 存货编码,存货名称,订单号,发货日期,客户主键,分仓,decode(分仓,'北京仓','001','南京仓','022','沈阳仓','017','西安仓','056','成都仓','051','哈尔滨仓','020') 仓库编码
,sum(数量) 销量,
sum(case when 发货日期 >= to_char(sysdate-31,'yyyy-mm-dd') then  数量 else 0 end) 三十天分仓销量,
case when 发货日期 >= to_char(sysdate-31,'yyyy-mm-dd') then  客户主键 else null end 三十天客户主键
 from (
select a.*,case when 客户分布 in ( '甘肃省','宁夏回族自治区','青海省','陕西省', '新疆维吾尔自治区') then '西安仓'
  when 客户分布 in ( '安徽省','广西壮族自治区','湖北省','湖南省', '江苏省', '上海市', '浙江省','江西省', '福建省', '广东省','海南省','台湾省', '香港特别行政区', '澳门特别行政区')then '南京仓' 
  when 客户分布 in ( '内蒙古自治区','河北省','河南省','北京市', '山东省','山西省', '天津市') then '北京仓'
  when 客户分布 in ( '贵州省','四川省','西藏自治区','云南省', '重庆市') then '成都仓'
  when 客户分布 in ( '黑龙江省') then '哈尔滨仓'
  when 客户分布 in ( '吉林省','辽宁省') then '沈阳仓' end as  分仓 from (
select distinct
s.vreceiptcode as 订单号,
s.dapprovedate as 发货日期,
s.vdef16 as 商桥备注,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
sb.nnumber as 数量,
decode(fstatus,1,'自由',2,'审核',6,'结束') as 状态,
s.pk_defdoc16 as 省份,
s.pk_defdoc20 as 城市,
vdef20 as 地址, 
s.ccustomerid 客户主键,
 case when s.pk_defdoc16 like '%北京%' then '北京市'
      when s.pk_defdoc16 like '%天津%' then '天津市'
      when s.pk_defdoc16 like '%河北%' then '河北省'
      when s.pk_defdoc16 like '%山西%' then '山西省'
      when s.pk_defdoc16 like '%内蒙%' and (pk_defdoc20 like '%通辽%'or pk_defdoc20 like '%呼伦贝尔%'or pk_defdoc20 like '%兴安盟%')  then '辽宁省'
      when s.pk_defdoc16 like '%内蒙%' then '内蒙古自治区'
      when s.pk_defdoc16 like '%辽宁%' then '辽宁省'
      when s.pk_defdoc16 like '%吉林%' then '吉林省'
      when s.pk_defdoc16 like '%黑龙江%' then '黑龙江省'
      when s.pk_defdoc16 like '%上海%' then '上海市'
      when s.pk_defdoc16 like '%江苏%' then '江苏省'
      when s.pk_defdoc16 like '%浙江%' then '浙江省'
      when s.pk_defdoc16 like '%安徽%' then '安徽省'
      when s.pk_defdoc16 like '%福建%' then '福建省'
      when s.pk_defdoc16 like '%江西%' then '江西省'
      when s.pk_defdoc16 like '%山东%' then '山东省'
      when s.pk_defdoc16 like '%河南%' then '河南省'
      when s.pk_defdoc16 like '%湖北%' then '湖北省'
      when s.pk_defdoc16 like '%湖南%' then '湖南省'
      when s.pk_defdoc16 like '%广东%' then '广东省'
      when s.pk_defdoc16 like '%广西%' then '广西壮族自治区'
      when s.pk_defdoc16 like '%海南%' then '海南省'
      when s.pk_defdoc16 like '%重庆%' then '重庆市'
      when s.pk_defdoc16 like '%四川%' then '四川省'
      when s.pk_defdoc16 like '%贵州%' then '贵州省'
      when s.pk_defdoc16 like '%云南%' then '云南省'
      when s.pk_defdoc16 like '%西藏%' then '西藏自治区'
      when s.pk_defdoc16 like '%陕西%' then '陕西省'
      when s.pk_defdoc16 like '%甘肃%' then '甘肃省'
      when s.pk_defdoc16 like '%青海%' then '青海省'
      when s.pk_defdoc16 like '%宁夏%' then '宁夏回族自治区'
      when s.pk_defdoc16 like '%新疆%' then '新疆维吾尔自治区'
      when s.pk_defdoc16 like '%台湾%' then '台湾省'
      when s.pk_defdoc16 like '%香港%' then '香港特别行政区'
      when s.pk_defdoc16 like '%澳门%' then '澳门特别行政区'
      when substr(vdef20,0,3) like '%北京%' then '北京市'
      when substr(vdef20,0,3) like '%天津%' then '天津市'
      when substr(vdef20,0,3) like '%河北%' then '河北省'
      when substr(vdef20,0,3) like '%山西%' then '山西省'
      when substr(vdef20,0,3) like '%内蒙%'and (vdef20 like '%通辽%'or vdef20 like '%呼伦贝尔%'or vdef20 like '%兴安盟%') then '辽宁省'
      when substr(vdef20,0,3) like '%内蒙%' then '内蒙古自治区'
      when substr(vdef20,0,3) like '%辽宁%' then '辽宁省'
      when substr(vdef20,0,3) like '%吉林%' then '吉林省'
      when substr(vdef20,0,3) like '%黑龙江%' then '黑龙江省'
      when substr(vdef20,0,3) like '%上海%' then '上海市'
      when substr(vdef20,0,3) like '%江苏%' then '江苏省'
      when substr(vdef20,0,3) like '%浙江%' then '浙江省'
      when substr(vdef20,0,3) like '%安徽%' then '安徽省'
      when substr(vdef20,0,3) like '%福建%' then '福建省'
      when substr(vdef20,0,3) like '%江西%' then '江西省'
      when substr(vdef20,0,3) like '%山东%' then '山东省'
      when substr(vdef20,0,3) like '%河南%' then '河南省'
      when substr(vdef20,0,3) like '%湖北%' then '湖北省'
      when substr(vdef20,0,3) like '%湖南%' then '湖南省'
      when substr(vdef20,0,3) like '%广东%' then '广东省'
      when substr(vdef20,0,3) like '%广西%' then '广西壮族自治区'
      when substr(vdef20,0,3) like '%海南%' then '海南省'
      when substr(vdef20,0,3) like '%重庆%' then '重庆市'
      when substr(vdef20,0,3) like '%四川%' then '四川省'
      when substr(vdef20,0,3) like '%贵州%' then '贵州省'
      when substr(vdef20,0,3) like '%云南%' then '云南省'
      when substr(vdef20,0,3) like '%西藏%' then '西藏自治区'
      when substr(vdef20,0,3) like '%陕西%' then '陕西省'
      when substr(vdef20,0,3) like '%甘肃%' then '甘肃省'
      when substr(vdef20,0,3) like '%青海%' then '青海省'
      when substr(vdef20,0,3) like '%宁夏%' then '宁夏回族自治区'
      when substr(vdef20,0,3) like '%新疆%' then '新疆维吾尔自治区'
      when substr(vdef20,0,3) like '%台湾%' then '台湾省'
      when substr(vdef20,0,3) like '%香港%' then '香港特别行政区'
      when substr(vdef20,0,3) like '%澳门%' then '澳门特别行政区'
      else null end 客户分布,
sc.storname 仓库 ,
sc.storcode ,
sb.nsummny as 价税合计
from nc5x.so_saleorder_b sb
join nc5x.so_sale s 
on s.csaleid = sb.csaleid and s.dr= 0
join nc5x.bd_invbasdoc cg
on cg.pk_invbasdoc = sb.cinvbasdocid 
left outer join  nc5x.bd_stordoc  sc
on s.cwarehouseid = sc.pk_stordoc
where s.dapprovedate  >= to_char(sysdate-91,'yyyy-mm-dd') 
and cg.width = '兼容'
) a  where 客户分布 is not null ) group by 存货编码,存货名称,订单号,发货日期,客户主键,分仓) group by 存货编码,存货名称,分仓,仓库编码 



-- and s.dapprovedate <like '2022-06-30'
-- s.vreceiptcode like '1867404036353614368'


-- select * from nc5x.so_sale  where  vreceiptcode like 'SO2304140115'
