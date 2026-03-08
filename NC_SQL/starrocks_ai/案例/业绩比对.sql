
select ma.存货主键,ma.存货编码,ma.存货名称,ma.品类,ma.大类,ma.品牌,ma.小类 ,
sum(哈尔滨销量) 哈尔滨销量,
max(哈尔滨销量) 哈尔滨最大值,
sum(哈尔滨销售频次)  哈尔滨销售频次,
sum(西安销量) 西安销量,
max(西安销量) 西安最大值,
sum(西安销售频次)  西安销售频次,
sum(南京销量) 南京销量,
max(南京销量) 南京最大值,
sum(南京销售频次)  南京销售频次,
sum(成都销量) 成都销量,
max(成都销量) 成都最大值,
sum(成都销售频次)  成都销售频次,
sum(北京销量) 北京销量,
max(北京销量) 北京最大值,
sum(北京销售频次)  北京销售频次,
sum(沈阳销量) 沈阳销量,
max(沈阳销量) 沈阳最大值,
sum(沈阳销售频次)  沈阳销售频次
 from ( select  ma.存货主键,ma.存货编码,ma.存货名称,ma.品类,ma.大类,ma.品牌,ma.小类 ,
case when ma.客户分仓 = '哈尔滨' then  ma.数量 else 0 end 哈尔滨销量,
 case when ma.客户分仓 = '哈尔滨' then  1 else 0 end 哈尔滨销售频次,
case when ma.客户分仓 = '西安' then  ma.数量 else 0 end 西安销量,
   case when ma.客户分仓 = '西安' then  1 else 0 end 西安销售频次,
case when ma.客户分仓 = '南京' then  ma.数量 else 0 end 南京销量,
   case when ma.客户分仓 = '南京' then  1 else 0 end 南京销售频次,
case when ma.客户分仓 = '成都' then  ma.数量 else 0 end 成都销量,
 case when ma.客户分仓 = '成都' then  1 else 0 end 成都销售频次,
case when ma.客户分仓 = '北京' then  ma.数量 else 0 end 北京销量,
   case when ma.客户分仓 = '北京' then  1 else 0 end 北京销售频次,
case when ma.客户分仓 = '沈阳' then  ma.数量 else 0 end 沈阳销量,
 case when ma.客户分仓 = '沈阳' then  1 else 0 end 沈阳销售频次,
 ma.客户分仓,ma.数量
 from (
 select ma.* ,
  nvl(case when regexp_like ( ma.客户分布,'(甘肃|宁夏|青海|陕西|新疆)') then '西安'
       when regexp_like (  ma.客户分布,'(吉林|辽宁)') then '沈阳'
             when regexp_like (  ma.客户分布,'(安徽|广西|湖北|湖南|江苏|上海|浙江|江西|福建|广东|海南)') then '南京'
               when  regexp_like (  ma.客户分布,'(黑龙江)') then '哈尔滨' 
                   when regexp_like (  ma.客户分布,'(贵州|四川|西藏|云南|重庆)') then '成都'
                          when regexp_like (  ma.客户分布,'(北京|河北|河南|内蒙古|山东|山西|天津)')  then '北京'
                        end, 客户分布) as 客户分仓  from ( select ii.csaleid as  主键 ,
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
       ib.invname as 存货名称,
       ib.blargessflag  as 是否赠品,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
      ck.storname as 出库仓库,
           case when regexp_like ( substr( m.vdef20,1,8),'(甘肃|宁夏|青海|陕西|新疆)') then '西安'
       when regexp_like ( substr( m.vdef20,1,8),'(吉林|辽宁)') then '沈阳'
             when regexp_like ( substr( m.vdef20,1,8),'(安徽|广西|湖北|湖南|江苏|上海|浙江|江西|福建|广东|海南)') then '南京'
               when  regexp_like ( substr( m.vdef20,1,8),'(黑龙江)') then '哈尔滨' 
                   when regexp_like ( substr( m.vdef20,1,8),'(贵州|四川|西藏|云南|重庆)') then '成都'
                          when regexp_like ( substr( m.vdef20,1,8),'(北京|河北|河南|内蒙古|山东|山西|天津)') or cu.sf is null  then '北京'
                          else cu.sf end 客户分布
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
  ii.dbilldate >'2021-10-01'  --and  m.vreceiptcode =  'SO2101281672'
 and ii.dr=0 
and ib.width  in ('兼容','原装','打印机') and ck.storname  not in ('首创虚拟库')   ) ma 
) ma )ma  group by ma.存货主键,ma.存货编码,ma.存货名称,ma.品类,ma.大类,ma.品牌,ma.小类




