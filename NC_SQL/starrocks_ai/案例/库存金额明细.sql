select  ma.大类,ma.库房,ma.日期 ,ma.品类,sum(ma.数量) from(
select 
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.dbdate as  日期,
cc.storname as 库房,
sum(js.nonhandnum)  as 数量,
sum(js.jcprice*js.nonhandnum) as 小类
from nc5x.story_num js
join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
on js.cinventoryid = cg.pk_invmandoc
join nc5x.bd_stordoc cc
on cc.pk_stordoc=js.cwarehouseid
where js.dbdate>='20210315'
and cc.storname in ('西安本部','西 安99库',
'成都本部',
'1号库',
'南京本部',
'中山仓',
'西安科贸',
'哈尔滨本部',
'沈阳本部',
'成都门市',
'重庆本部',
'南 京99库' ) and  cg.width in ('原装','兼容','打印机') group by   cg.width,cg.length,cg.invpinpai,cg.height,js.dbdate,cc.storname ) ma  group by  ma.大类,ma.库房,ma.日期,ma.品类

