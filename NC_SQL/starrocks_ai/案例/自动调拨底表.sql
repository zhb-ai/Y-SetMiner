
select ma.存货主键,ma.存货编码,ma.存货名称,ma.品类,ma.大类,ma.品牌,ma.小类 ,
sum(哈尔滨销量) 哈尔滨销量,
max(哈尔滨销量) 哈尔滨最大值,
count(distinct 哈尔滨销售频次)  哈尔滨销售频次,
sum(西安销量) 西安销量,
max(西安销量) 西安最大值,
count(distinct 西安销售频次)  西安销售频次,
sum(南京销量) 南京销量,
max(南京销量) 南京最大值,
count(distinct 南京销售频次)  南京销售频次,
sum(成都销量) 成都销量,
max(成都销量) 成都最大值,
count(distinct 成都销售频次)  成都销售频次,
sum(北京销量) 北京销量,
max(北京销量) 北京最大值,
count(distinct 北京销售频次)  北京销售频次,
sum(沈阳销量) 沈阳销量,
max(沈阳销量) 沈阳最大值,
count(distinct 沈阳销售频次)  沈阳销售频次
 from ( select  ma.存货主键,ma.存货编码,ma.存货名称,ma.品类,ma.大类,ma.品牌,ma.小类 ,ma.订单号,ma.客户分仓,
sum(case when ma.客户分仓 = '哈尔滨' then  ma.数量 else 0 end) 哈尔滨销量,
 case when ma.客户分仓 = '哈尔滨' then ma.订单号 else '0' end 哈尔滨销售频次,
sum(case when ma.客户分仓 = '西安' then  ma.数量 else 0 end) 西安销量,
  case when ma.客户分仓 = '西安'  then ma.订单号 else '0' end 西安销售频次,
sum(case when ma.客户分仓 = '南京' then  ma.数量 else 0 end) 南京销量,
   case when ma.客户分仓 = '南京'  then ma.订单号 else '0' end 南京销售频次,
sum(case when ma.客户分仓 = '成都' then  ma.数量 else 0 end) 成都销量,
 case when ma.客户分仓 = '成都' then ma.订单号 else '0' end 成都销售频次,
sum(case when ma.客户分仓 = '北京' then  ma.数量 else 0 end) 北京销量,
   case when ma.客户分仓 = '北京' then ma.订单号 else '0'  end 北京销售频次,
sum(case when ma.客户分仓 = '沈阳' then  ma.数量 else 0 end) 沈阳销量,
 case when ma.客户分仓 = '沈阳' then ma.订单号 else '0' end 沈阳销售频次
 from (
 select ma.* ,
 case when ma.客户分布 in ( '甘肃省','宁夏回族自治区','青海省','陕西省', '新疆维吾尔自治区') then '西安'
  when ma.客户分布 in ( '安徽省','广西壮族自治区','湖北省','湖南省', '江苏省', '上海市', '浙江省','江西省', '福建省', '广东省','海南省','台湾省', '香港特别行政区', '澳门特别行政区')then '南京' 
  when ma.客户分布 in ( '内蒙古自治区','河北省','河南省','北京市', '山东省','山西省', '天津市') then '北京'
  when ma.客户分布 in ( '贵州省','四川省','西藏自治区','云南省', '重庆市') then '成都'
  when ma.客户分布 in ( '黑龙江省') then '哈尔滨'
  when ma.客户分布 in ( '吉林省','辽宁省') then '沈阳'
  end as  客户分仓  from ( select ii.csaleid as  主键 ,
    cu.deptname as  市场部,
    cu.n_deptname as  部门,
    cu.psnname as  业务员,
cu.pk_cumandoc  as 客户主键,
case when ii.vnote like '%\%' then '0' else ii.vnote  end  as 备注,
m.vreceiptcode,
  ib.nnumber as 数量,
 substr(to_char(to_date(ii.dbilldate,'yyyy-mm-dd') ,'yyyy-mm-dd'),1,10)as 日期,
     yw.businame as 业务类型,
       ib.cinvbasdocid as 存货主键,
       ib.invcode as 存货编码,
       ib.CORIGINALBILLCODE as 订单号,
       ib.invname as 存货名称,
       ib.blargessflag  as 是否赠品,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
      ck.storname as 出库仓库,
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
  ii.dbilldate > to_char(sysdate - 100,'yyyy-mm-dd')
 and ii.dr=0 
and ib.width  in ('兼容','原装','打印机') and ck.storname  not in ('首创虚拟库')) ma 
) ma group by  ma.存货主键,ma.存货编码,ma.存货名称,ma.品类,ma.大类,ma.品牌,ma.小类 ,ma.订单号,ma.客户分仓 ) ma  group by ma.存货主键,ma.存货编码,ma.存货名称,ma.品类,ma.大类,ma.品牌,ma.小类




