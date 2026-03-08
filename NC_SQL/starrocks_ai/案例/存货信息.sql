select
us.user_name 修改人,
aa.modifytime 修改时间,
bb.pk_invbasdoc 存货主键,
aa.invcode as 存货编码,
aa.invname  as 存货名称,
aa.invpinpai   as 品牌 ,
aa.width as 大类 ,
aa.length as 品类 ,
aa.height as 小类 , 
aa.unitvolume as 体积,
aa.unitweight as  重量,
aa.invtype     as 型号 ,
aa.def10 as 供应商,
aa.def2  as 装箱数,
case 
  when INSTR(aa.def19,'-',-1,1) >0 then  substr(aa.def19,1,INSTR(aa.def19,'-',-1,1)-1)
  when INSTR(aa.def19,'A-',-1,1) > 0 then substr(aa.def19,1,INSTR(aa.def19,'A-',-1,1)-1) 
ELSE '未匹配' END  as 型号s,
case 
  when INSTR(aa.invtype,'-',-1,1) >0 then  substr(aa.invtype,1,INSTR(aa.invtype,'-',-1,1)-1)
  when INSTR(aa.invtype,'A-',-1,1) > 0 then substr(aa.invtype,1,INSTR(aa.invtype,'A-',-1,1)-1) 
ELSE '未匹配' END  as 型号sss,
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
left join nc5x.sm_user  us
on us.cuserid= aa.modifier
where 
aa.width  in ('原装')
and bb.sealflag  = 'N'
and aa.length like '%复印%'
-- and aa.invname like '%【%'


--aa.invcode  = '2005051-1'
-- and aa.invname like '%懿智通YZT 惠普CB436/CC388A系列黑色碳粉(70G)%'


select
us.user_name 修改人,
aa.modifytime 修改时间,
bb.pk_invbasdoc 存货主键,
aa.invcode as 存货编码,
aa.invname  as 存货名称,
aa.invpinpai   as 品牌 ,
aa.width as 大类 ,
aa.length as 品类 ,
aa.height as 小类 , 
aa.unitvolume as 体积,
aa.unitweight as  重量,
aa.invtype     as 型号 ,
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
left join nc5x.sm_user  us
on us.cuserid= aa.modifier
where 
aa.width  in ('兼容')

and bb.sealflag  = 'Y'
