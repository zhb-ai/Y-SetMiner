
 select * from(
select * from(

SELECT cum.deptcode as 部门编码,cum.deptname as 市场部,cum.n_deptname as 部门,cum.psnname as 业务员,dq.sf as 省份,dq.cs as 城市,cub.mobilephone3 as 服务行业,cub.bp3 as 客户类型,
       (case when (cum.sealflag is not null or length(ltrim(rtrim(cum.sealflag))) > 0 ) then 'Y' ELSE 'N' END ) as 是否封存,
       (case when cub.def3 = '0001C11000000012TJ3X' then '商桥' else '' end) as 商桥,
       cub.custcode as 客户编码,cub.custname as 客户名称,cub.def10 as 开票名称,
       redit.nlimitmny as 额度,
       (case when cum.termid = '01' then 0 else to_number(cum.termid) end ) as 账期,
       substr(cub.createtime,0,10) as 建档日期,
       redits.nlimitmny as 放货额度,
       cum.innerctldays as 放货账期,
      cum.pk_cumandoc as 客户主键,cum.pk_cubasdoc,cub.linkman1 as 联系人,case when cub.phone1 ='/' or cub.phone1 ='\'then '0' else cub.phone1 end  as 电话,
       case when cub.mobilephone1 ='/' or cub.mobilephone1 ='\'then '0' else cub.mobilephone1 end  as 手机,
       case when cub.bp1='/' or  cub.bp1='\' then '0' else cub.bp1 end  as QQ微信,cub.conaddr as 地址
  FROM nc5x.bd_cubasdoc cub
  join (select substr(deptcode,1,4) deptcode,
                (case
                 when substr(dept.deptcode, 1, 6) in ( '030400','030441')  then
                  '区域销售部'
                 when substr(dept.deptcode, 1, 4) = '0303' then
                  '北京市场部'
                 when substr(dept.deptcode, 1, 4) = '0304' then
                  '外阜市场部'
                 when substr(dept.deptcode, 1, 2) = '10' then
                  '直营+微分销'
                 else dept.deptname end) deptname,
               dept.deptname n_deptname,
               psn.psnname psnname,
               pay.termname,
               pay.termid,
               cum.*
          from nc5x.bd_cumandoc cum
            join nc5x.bd_deptdoc dept
              on cum.pk_respdept1 = dept.pk_deptdoc
            join nc5x.bd_psndoc psn
              on cum.pk_resppsn1 = psn.pk_psndoc
            left join nc5x.bd_payterm pay
              on cum.pk_payterm = pay.pk_payterm
                 and cum.dr = 0
          where cum.custflag in ('0', '2')
            and cum.pk_corp = '1006'
            and cum.dr = 0)cum
    on cub.pk_cubasdoc = cum.pk_cubasdoc and cub.dr = 0
  left join(select cl.pk_areacl,c.areaclname sf,cl.areaclname cs 
              from nc5x.bd_areacl c 
              left join nc5x.bd_areacl cl 
                on c.pk_areacl = cl.pk_fatherarea)dq 
       on cub.pk_areacl = dq.pk_areacl
  left join nc5x.so_cucredit redit
       on cub.pk_cubasdoc = redit.pk_cubasdoc
       and redit.climittypeid = '0001A110000000002EXU'
       and redit.vcredittypename = '2'
       and redit.dr =0
  left join nc5x.so_cucredit redits
       on cub.pk_cubasdoc = redits.pk_cubasdoc
       and redits.climittypeid = '0001A110000000002EXV'
       and redits.vcredittypename = '2'
       and redits.dr =0
  --where cum.deptname <> '直营+微分销'
 order by cum.pk_cumandoc asc ) d left join 
 
(
select 
ii.creceiptcustomerid 客户主键,
min(ii.dbilldate) as 首次交易日期
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
where (1=1)
--ii.dbilldate>= '2020-11-01'
and  ii.dr=0 
and ib.width  in ('兼容','原装','打印机')
and ii.creceiptcustomerid is not null  
--AND cu.deptname <>'直营+微分销' 
group by ii.creceiptcustomerid  order by  ii.creceiptcustomerid asc) c
on d.客户主键=c.客户主键
left join 
(select cuc.pk_cumandoc 子客户主键 ,substr(cum.createtime,0,10) as 主客户建档日期,cuml.主客户主键
from nc5x.bd_cubasdoc cum   join 
(select   pk_cubasdoc 子客户主键,custcode 子客户编码,custname  子客户名称,pk_cubasdoc1 主客户主键    from nc5x.bd_cubasdoc  where  pk_cubasdoc1 is not null ) cuml 
on cuml.主客户主键= cum.pk_cubasdoc 
left join 
 nc5x.bd_cumandoc cuc
on cum.pk_cubasdoc = cuc.pk_cubasdoc and cum.dr = 0  order by cuml.子客户主键  asc  ) a
 on a.子客户主键 = d.客户主键 ) gs where gs.首次交易日期 is not  null 
