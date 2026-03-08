SELECT cum.deptcode as 部门编码,cum.deptname as 市场部,cum.n_deptname as 部门,cum.psnname as 业务员,dq.sf as 省份,dq.cs as 城市,cub.mobilephone3 as 服务行业,cub.bp3 as 客户类型,
       (case when (cum.sealflag is not null or length(ltrim(rtrim(cum.sealflag))) > 0 ) then 'Y' ELSE 'N' END ) as 是否封存,
       (case when cub.def3 = '0001C11000000012TJ3X' then '商桥' else '' end) as 商桥,cum.pk_cumandoc,cum.pk_cubasdoc,
       cub.custcode as 客户编码,cub.custname as 客户名称,cub.def10 as 开票名称,
       redit.nlimitmny as 额度,
       (case when cum.termid = '01' then 0 else to_number(cum.termid) end ) as 账期,
       substr(cub.createtime,0,10) as 建档日期,
       redits.nlimitmny as 放货额度,
       cum.innerctldays as 放货账期,
       cub.pk_cubasdoc,cum.pk_cumandoc,cub.linkman1 as 联系人,cub.phone1 as 电话,cub.mobilephone1 as 手机,cub.bp1 as QQ微信,cub.conaddr as 地址,cu.docname as 默认物流,cs.storname as 默认库房
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
            and cum.dr = 0 
            ) cum
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
  left join ( select de.docname,cu.pk_cubasdoc from nc5x.bd_cumandoc cu
        join nc5x.bd_defdoc de
          on cu.def8= de.pk_defdoc ) cu
  on cub.pk_cubasdoc = cu.pk_cubasdoc
  left join (select ck.storname, cs.pk_cubasdoc from nc5x.bd_cumandoc cs
        join nc5x.bd_stordoc ck
          on cs.pk_stordoc2= ck.pk_stordoc ) cs
 on cub.pk_cubasdoc = cs.pk_cubasdoc 
 where 
 (1=1)  and (case when (cum.sealflag is not null or length(ltrim(rtrim(cum.sealflag))) > 0 ) then 'Y'ELSE 'N'END)  = 'N' 
 and cum.psnname ='刘喜丹'
 order by cum.deptname,cum.n_deptname,cum.psnname,dq.sf,dq.cs,cub.bp3,cub.mobilephone3,cub.custcode,cub.custname,redit.nlimitmny,cum.termname asc
