SELECT 
distinct 
 to_char(add_months(sysdate,-6),'yyyy-mm-dd'),
ii.max_date,
ii.采购次数,
ii.兼容流水,
ii.原装流水,
ii.creceiptcustomerid,
cum.pk_cubasdoc,
cub.pk_cubasdoc as customer_key, -- 客户主键
cub.pk_cubasdocs as customer_keys,
cum.pk_cumandoc,
case when ii.creceiptcustomerid is not null then 'Y' else 'N' end buy_flag,
dq.sf as province, -- 省份
dq.cs as city, -- 城市
cub.mobilephone3 as service_trade,  -- 服务行业
cub.bp3 as customer_type,  -- 客户类型
(case when cub.def3 = '0001C11000000012TJ3X' then '商桥' else '' end) as sq, -- 商桥
cub.custcode as customer_node,  -- 客户编码
cub.custname as customer_name,  -- 客户名称
substr(cub.createtime,0,10) as create_time, -- 建档日期
cub.linkman1 as contact,  -- 联系人
cub.phone1 as phone,  -- 电话
cub.mobilephone1 as mobile_phone, -- 手机
cub.bp1 as qq_wechat,  -- QQ 微信
cub.conaddr as address
FROM ( 
select distinct cub.*,
cum1.子客户主键,
case when cum1.子客户主键 is not null  then cum1.主客户主键 else pk_cubasdoc end pk_cubasdocs 
from 
nc5x.bd_cubasdoc cub
 left join (
select pk_cubasdoc 子客户主键,pk_cubasdoc1 主客户主键 
from nc5x.bd_cubasdoc  
where  pk_cubasdoc1 is not null ) cum1 on cub.pk_cubasdoc =  cum1.子客户主键
 ) cub
join nc5x.bd_cumandoc cum on cub.pk_cubasdocs = cum.pk_cubasdoc and cub.dr = 0 
and (cum.sealflag is  null or length(cum.sealflag)=0)  
 and cum.dr=0
 and cum.custflag in ('0', '2')
 and cum.pk_corp = '1006'
left join
(select cl.pk_areacl,c.areaclname sf,cl.areaclname cs from nc5x.bd_areacl c left join nc5x.bd_areacl cl on c.pk_areacl = cl.pk_fatherarea)dq on cub.pk_areacl = dq.pk_areacl
left join 
( select ii.creceiptcustomerid,max(dbilldate) max_date,count(distinct dbilldate) 采购次数, sum(case when ib.width ='兼容' then ib.noriginalcurmny else 0 end) 兼容流水,sum(case when ib.width in ('原装','打印机') then ib.noriginalcurmny else 0 end) 原装流水 from nc5x.so_saleinvoice ii 
  join (select ib.csaleid,ch.width,ib.noriginalcurmny,ch.invcode
          from nc5x.so_saleinvoice ii 
          LEFT JOIN 
          nc5x.so_saleinvoice_b ib
          on ib.csaleid = ii.csaleid
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc
             ) ib
    on ib.csaleid = ii.csaleid
where dbilldate >= to_char(add_months(sysdate,-6),'yyyy-mm-dd') and dr=0 and length(ib.invcode) > 4 
group by ii.creceiptcustomerid

) ii on ii.creceiptcustomerid = cum.pk_cumandoc 
join nc5x.bd_psndoc psn on cum.pk_resppsn1 = psn.pk_psndoc
join nc5x.bd_deptdoc dept on cum.pk_respdept1 = dept.pk_deptdoc
where  psn.psnname<> '管理员' and substr(dept.deptcode, 1, 2) <> '10' 
 and  ((ii.creceiptcustomerid is  not null  and ii.采购次数 <3 and nvl(ii.兼容流水,0)=0 and ii.原装流水<5000 )or ii.creceiptcustomerid  is null ) 
and cub.子客户主键 is   null 
order by dq.sf,dq.cs,cub.bp3,cub.mobilephone3,cub.custcode,cub.custname 




