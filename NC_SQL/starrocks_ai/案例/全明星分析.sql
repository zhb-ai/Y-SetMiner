
select ma.*,case when (ma.original_achievement > 0 or ma.printer_achievement> 0) and ma.compatible_achievement <= 0  then '缺少兼容合作'  
when ma.main_drum > 0 and ma.brother_association > 0 and ma.color_drum > 0 and ma.black_drum > 0  and ma.duplicate > 0 and ma.ribbon > 0   then 'A类-品类齐全' 
                 when ma.main_drum > 0 and ma.brother_association > 0 and ma.color_drum > 0 and ma.black_drum > 0  then 'B类-主流品类齐全' 
                 when ma.main_drum <=  0 and ma.black_drum > 0 and (ma.brother_association <= 0  and  ma.color_drum <= 0   )  then 'C类-重点开发'
                   when ma.compatible_achievement> 0and  ma.main_drum > 0 and ma.brother_association  >  0 and ma.color_drum<= 0 and ma.black_drum >  0 then '关注彩色扩品'
                 when ma.compatible_achievement> 0and  ma.main_drum <= 0 and ma.brother_association <= 0 and ma.color_drum<= 0 and ma.black_drum <= 0 then '需重新判断其价值'
                    when ma.duplicate <= 0 then '复印类扩品' 
                   else '关注扩品'  end  classification_level
                   from（
select ma.部门1 as department ,ma.业务员 as sales_man ,ma.客户名称 as customer_name ,sum(ma.主流) as main_drum,
sum(ma.兄弟联想) brother_association,
sum(ma.彩鼓) color_drum,
sum(ma.黑鼓) black_drum,
sum(ma.碳粉) toner,
sum(ma.色带) ribbon,
sum(ma.复印类) duplicate,
sum(ma.原装流水) original_achievement,
sum(ma.兼容流水) compatible_achievement,
sum(ma.打印机流水) printer_achievement
 from (select
ma.部门1,
ma.业务员,ma.客户名称,sum(case when ma.大类 = '兼容' and ma.品类 = '硒鼓' and (ma.存货名称 like '%388%'or ma.存货名称 like '%2612%') then ma.数量 else 0 end ) as  主流,
sum(case when ma.大类 = '兼容' and  ma.品类 = '硒鼓' and (ma.存货名称 like '%DR%'or ma.存货名称 like '%TN%'or ma.存货名称 like '%LD%'or ma.存货名称 like '%LT%') then ma.数量 else 0 end ) AS 兄弟联想,
sum(case when ma.大类 = '兼容' and  ma.品类 = '硒鼓' and ma.小类 ='彩色' then ma.数量 else 0 end) 彩鼓,
sum(case when ma.大类 = '兼容' and  ma.品类 = '硒鼓' and ma.小类 ='黑色' then ma.数量 else 0 end) 黑鼓,
sum(case when ma.大类 = '兼容' and  ma.品类 = '碳粉' then ma.数量 else 0 end) 碳粉,
sum(case when ma.大类 = '兼容' and  ma.品类 like '%色带%' then ma.数量 else 0 end) 色带,
sum(case when ma.大类 = '兼容' and  ma.品类 like  '%复印%' then ma.数量 else 0 end ) 复印类,
sum(case when ma.大类 = '原装'  then ma.数量 else 0 end) 原装流水,
sum(case when ma.大类 = '打印机'  then ma.数量 else 0 end) 打印机流水,
sum(case when ma.大类 = '兼容'and  ( ma.品类 not in ( '硒鼓') or  ma.品类 not like  '%复印%') then ma.数量 else 0 end) 兼容流水
 from (
  select ii.csaleid ,
  ib.pk_invbasdoc,
 ii.VRECEIPTCODE as 单号,
    ii.dbilldate as 日期,
    substr(ii.dbilldate,1,7) as 月份 ,
    cu.deptname as 市场部 ,
    cu.n_deptname as 部门 ,
    cu.psnname as 业务员 ,  
 case when cu.deptname ='北京市场部' and cu.n_deptname like '%盛购%' then '北京-盛购'
   when cu.deptname ='北京市场部' and cu.n_deptname like '%科贸%' then '北京-科贸'
   when cu.deptname ='北京市场部'  and (cu.n_deptname not  like '%科贸%' or cu.n_deptname not  like '%盛购%') then '北京-市场业务部'
   when cu.n_deptname like '%沈阳%' then '沈阳分公司'
   when cu.n_deptname like '%成都%' then '成都分公司'
   when cu.n_deptname like '%南京%' then '南京分公司'
   when cu.n_deptname like '%哈尔滨%' then '哈尔滨分公司'
   when cu.n_deptname like '%西安%' then '西安分公司'
   when cu.n_deptname like '%重庆%' then '重庆分公司'
     when cu.deptname ='SI业务部' then 'SI业务部'
       when cu.deptname ='区域销售部' then '区域销售部'
   when  cu.psnname like '%冯彩霞%'or cu.psnname like '%霍宇飞%' then '大客户部'
    when cu.psnname like '%李东伟%'or cu.psnname  like '%刘喜丹%' then '平台业务部'
      when cu.n_deptname  like '%渠道部%'  then '渠道部'else '其他' end 部门1,
        case when cu.deptname ='北京市场部' then '北京市场部'
          when cu.deptname ='外阜市场部' then '外阜市场部'
            when cu.deptname ='SI业务部' then 'SI业务部'
              when cu.deptname ='区域销售部' then '区域销售部'
                when cu.n_deptname  like '%渠道部%'  then '渠道部'
                     when cu.psnname like '%冯彩霞%'or cu.psnname like '%霍宇飞%' then '大客户部'
    when cu.psnname like '%李东伟%'or cu.psnname like '%刘喜丹%' then '平台业务部'else '其他' end 市门,
cu.pk_cumandoc 客户主键 ,
cu.custcode as 客户编码 ,
cu.custname as 客户名称 ,
 cu.sf as 省 ,
       cu.cs as 市 ,
       II.VDEF7 AS 货运公司,
    ii.dr ,
  m.vdef20 as 地址,
  --  (case when ib.nsummny =0 or  ib.nsummny is null then 0.1 else  ib.nsummny end)/(case when ib.nnumber =0 or  ib.nnumber is null then 0.1 else  ib.nnumber end) as 单价 ,
      yw.businame as 业务类型,
       ii.vnote as 备注,
       ib.nnumber as 数量,
       ib.nsummny as 价税合计,
       ib.blargessflag  as 是否赠品,
       translate( ib.invname,'#'||translate( ib.invname ,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','#') ,'/')as 型号  ,
       translate( ib.invname,'#'||translate( ib.invname ,'0123456789','#') ,'/')as 型号1  ,
        ib.invcode as 存货编码,
       ib.invname as 存货名称,
       ib.length as 品类,
       ib.width as 大类,
       ib.height as 小类,
       ib.invpinpai as 品牌,
       ck.storname as 库房,
    case when  yw.busicode = 's005' then '放货'else '销售'end 是否放货
  from nc5x.so_saleinvoice ii
  join (select  ib.coriginalbillcode,ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc ) ib
    on ib.csaleid = ii.csaleid
    left  join  nc5x.so_sale m 
 on ib.coriginalbillcode =m.vreceiptcode
  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcustomerid = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc ck
    on ii.cwarehouseid = ck.pk_stordoc
    
 where 
  ii.dbilldate >'2020-04-17'
 and ii.dr=0 
   )ma 
  where
  ma.日期 >= '2021-01-01'and ma.大类 in ('兼容','原装','打印机') 
  and ma.库房 <> '首创虚拟库' and ma.客户名称 is not null 
  group by ma.部门1,ma.业务员,ma.客户名称 ,ma.存货名称 ) ma  group by ma.部门1,ma.业务员,ma.客户名称
    order by  sum(ma.兼容流水) 
    desc
    ) ma
