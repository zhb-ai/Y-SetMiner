select 
aa.invcode || '|'|| cc.invcode as RK,
aa.invcode as 存货编码,
aa.invname as 存货名称,
cc.invcode,
cc.invname,
cc.bindlenum,
cc.refsaleprice,
bb.refsaleprice as 批发售价,
bb.lowestprice  as 最低限价
from nc5x.bd_invmandoc bb
join nc5x.bd_invbasdoc aa
on aa.pk_invbasdoc = bb.pk_invbasdoc
join (select ee.invcode,ee.invname,dd.bindlenum,dd.pk_invmandoc ,ee.refsaleprice
from nc5x.bd_invbindle dd 
join  (select ff.pk_invmandoc,gg.invname,gg.invcode,
ff.refsaleprice
 from nc5x.bd_invmandoc ff join nc5x.bd_invbasdoc gg on ff.pk_invbasdoc = gg.pk_invbasdoc)ee
on ee.pk_invmandoc = dd.pk_bindleinvmandoc )cc
on cc.pk_invmandoc = bb.pk_invmandoc




select 
aa.invcode as 存货编码,
aa.invname as 存货名称,
aa.width as 大类 ,
aa.length as 品类 ,
aa.height as 小类 , 
aa.invpinpai   as 品牌 ,
cc.最新价格,
cc.产品个数,
cc.存货数量,
bb.refsaleprice as 原价格,
bb.lowestprice  as 最低限价
from nc5x.bd_invmandoc bb
join nc5x.bd_invbasdoc aa
on aa.pk_invbasdoc = bb.pk_invbasdoc
join (

select dd.pk_invmandoc ,sum(ee.refsaleprice* dd.bindlenum) 价格,sum(dd.bindlenum)产品个数 ,count(ee.invcode) 存货数量
from nc5x.bd_invbindle dd 
join  (select ff.pk_invmandoc,gg.invname,gg.invcode,
ff.refsaleprice
from nc5x.bd_invmandoc ff join nc5x.bd_invbasdoc gg on ff.pk_invbasdoc = gg.pk_invbasdoc)ee
on ee.pk_invmandoc = dd.pk_bindleinvmandoc 
group by dd.pk_invmandoc) cc 
on cc.pk_invmandoc = bb.pk_invmandoc


