select
substr(aa.modifytime,1,10) 修改日期,
bb.pk_invmandoc  存货管理档案主键,
aa.invcode as 存货编码,
aa.invname  as 主存货名称,
ac.invname  as 捆绑件存货名称,
aa.invpinpai   as 品牌 ,
aa.width as 大类 ,
aa.length as 品类 ,
aa.height as 小类 , 
aa.MEMO as 长宽高,
aa.unitvolume as 体积,
aa.unitweight as  重量,
aa.invtype  as 型号 ,
aa.def13 标贴名称,
aa.def7 备注信息后台,
aa.def10 as 供应商,
aa.def2  as 装箱数,
aa.invbarcode  as 条码 ,
aa.def19       as 税票型号 ,
bb.refsaleprice as 批发售价,
bb.lowestprice  as 最低限价,
decode(bb.def2,0,bb.def1) as 零售指导价,
aa.def3 as ISBEIHUO,
bb.def5 as 代理价 ,
bb.sealflag  as 是否封存  
from nc5x.bd_invbasdoc aa 
join nc5x.bd_invmandoc bb 
on aa.pk_invbasdoc = bb.pk_invbasdoc
left join  nc5x.bd_invbindle  bl
on bb.pk_invmandoc = bl.pk_invmandoc
left join nc5x.bd_invmandoc a
on  bl.pk_bindleinvmandoc = a.pk_invmandoc
left join nc5x.bd_invbasdoc ac
on ac.pk_invbasdoc = a.pk_invbasdoc
left join nc5x.sm_user  us
on us.cuserid= aa.modifier
where (1=1)
-- and aa.invpinpai  not like '%虚拟套装%'
-- and aa.width  in ('兼容')
and  bb.sealflag  = 'N'
and bl.pk_invmandoc is not null 
-- and  bb.pk_invmandoc  = '1006C1100000003EF3TE'


-- and aa.invcode= '120021' 
-- and substr(aa.modifytime,1,10) = to_char(sysdate,'yyyy-mm-dd')  






-- select * from nc5x.bd_invbindle where pk_invmandoc    = '1006C110000000GTHW4V'




