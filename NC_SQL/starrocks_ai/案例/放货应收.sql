
 select  cu.部门,cu.业务员,cu.客户名称,
 case when cu.cse =  '一到三天' then sum(cu.余额) else null end 一到三天,
  case when cu.cse =  '四到十天' then sum(cu.余额) else null end 四到十天,
      case when cu.cse =  '十一到三十天' then sum(cu.余额) else null end 十一到三十天,
          case when cu.cse =  '三十到九十天' then sum(cu.余额) else null end 三十到九十天,
              case when cu.cse =  '九十天以上' then sum(cu.余额) else null end 九十天以上,
                case when cu.cse =  '正常' then sum(cu.余额) else null end 账期内,
                  sum(cu.余额) as 余额,sum(负余额)as 负余额
    from (
  select cu.deptname 部门 ,cu.psnname 业务员,cu.custname 客户名称,cu.hbbm 伙伴编码 ,cu.czq 超账期,cu.dr,cu.djbh,
  case when cu.czq>0 then '账期外'else '账期内'end 是否超期, 
  case when cu.czq>0 and cu.czq<=-3 then '一到三天'
  when  cu.czq>3 and cu.czq<=10 then '四到十天'
    when cu.czq>10 and cu.czq<=30 then '十一到三十天'
    when cu.czq>30 and cu.czq<=90 then '三十到九十天'
     when cu.czq>90  then '九十天以上'else '正常'end cse ,
  sum(余额)as 余额,sum(负余额)as 负余额 from  (
  select js.djbh,js.dr,hbbm ,cu.deptname,cu.psnname,cu.custname,
  case when js.djbh like '%SK%' then -abs(bbye) else bbye end 余额,
     case when js.djbh like '%SK%' then -abs(bbye) else 0  end 负余额
  ,billdate 日期,ter.termid as das,
   to_date(to_char( sysdate,'yyyy-mm-dd'),'yyyy-mm-dd')-to_date(js.billdate,'yyyy-mm-dd') - ter.termid as czq
  from nc5x.arap_djfb js left join  nc5x.v_zlw_cust cu 
  on  js.hbbm  = cu.pk_cubasdoc 
  left join nc5x.bd_payterm ter 
  on js.sfkxyh = ter.pk_payterm --where js.bbye<>0
  )cu  where  cu.custname   is not null  and cu.dr =0
  -- and cu.custname ='辽宁聚全云科技有限公司'
  group by cu.psnname,cu.custname,cu.hbbm ,cu.czq ,cu.deptname,cu.dr,cu.djbh
  ) cu  group by  cu.部门,cu.业务员,cu.客户名称,cu.cse
