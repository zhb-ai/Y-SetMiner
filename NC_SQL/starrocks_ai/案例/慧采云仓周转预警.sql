select 
存货编码
,sum(北京慧采销量)北京慧采销量
,sum(北京云仓销量)北京云仓销量
,sum(南京慧采销量)南京慧采销量
,sum(南京云仓销量)南京云仓销量
,sum(中山慧采销量)中山慧采销量
,sum(中山云仓销量)中山云仓销量
,sum(数量) 合并销量
,count(北京慧采订单量)北京慧采订单量
,count(北京云仓订单量)北京云仓订单量
,count(南京慧采订单量)南京慧采订单量
,count(南京云仓订单量)南京云仓订单量
,count(中山慧采订单量)中山慧采订单量
,count(中山云仓订单量)中山云仓订单量

,max(北京慧采销量) 北京慧采最大值
,max(北京云仓销量) 北京云仓最大值
,max(南京慧采销量) 南京慧采最大值
,max(南京云仓销量) 南京云仓最大值
,max(中山慧采销量) 中山慧采最大值
,max(中山云仓销量) 中山云仓最大值
from (
select 
库房编码
,存货编码
,订单号
,case when 库房编码 = '086' then 订单号 else null end 北京慧采订单量
,case when 库房编码 = '084' then 订单号 else null end 北京云仓订单量
,case when 库房编码 = '087' then 订单号 else null end 南京慧采订单量
,case when 库房编码 = '154' then 订单号 else null end 南京云仓订单量
,case when 库房编码 = '07603' then 订单号 else null end 中山慧采订单量
,case when 库房编码 = '07602' then 订单号 else null end 中山云仓订单量
,sum(数量)数量
,sum(北京慧采销量)北京慧采销量
,sum(北京云仓销量)北京云仓销量
,sum(南京慧采销量)南京慧采销量
,sum(南京云仓销量)南京云仓销量
,sum(中山慧采销量)中山慧采销量
,sum(中山云仓销量)中山云仓销量
from (
select
ib.invcode as 存货编码,
ib.invname as 存货名称, 
ii.dbilldate as 日期,
m.vreceiptcode as 订单号,
cu.custcode as 客户编码,
cu.custname as 客户名称 ,
-- II.VDEF7 AS 货运公司,
-- ii.dr 删除标志 ,
-- yw.businame as 业务类型,
-- ii.vnote as 备注,
ib.nnumber as 数量,
ib.width as 大类,
ib.height as 小类,
ib.invpinpai as 品牌,
ck.storcode 库房编码,
ck.storname as 库房 
,case when ck.storcode = '086' then ib.nnumber else 0 end 北京慧采销量
,case when ck.storcode = '084' then ib.nnumber else 0 end 北京云仓销量
,case when ck.storcode = '087' then ib.nnumber else 0 end 南京慧采销量
,case when ck.storcode = '154' then ib.nnumber else 0 end 南京云仓销量
,case when ck.storcode = '07603' then ib.nnumber else 0 end 中山慧采销量
,case when ck.storcode = '07602' then ib.nnumber else 0 end 中山云仓销量
from nc5x.so_saleinvoice ii
join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode,ib.nmny
from nc5x.so_saleinvoice_b ib
join nc5x.bd_invbasdoc ch
on ib.cinvbasdocid = ch.pk_invbasdoc
) ib
on ib.csaleid = ii.csaleid
left join nc5x.v_zlw_cust cu 
on ii.creceiptcorpid = cu.pk_cumandoc
LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
left join nc5x.bd_stordoc ck
on ii.cwarehouseid = ck.pk_stordoc
left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.sm_user  su1 
on m.coperatorid = su1.cuserid
left join nc5x.v_zlw_cust cuu 
on m.creceiptcorpid = cuu.pk_cumandoc
left join nc5x.bd_defdoc bd 
on ii.PK_DEFDOC5 = bd.PK_DEFDOC  
left join nc5x.bd_defdoc bdd 
on m.PK_DEFDOC5 = bdd.PK_DEFDOC  
where   
ii.dr=0 
and length(invcode) >= 5 
and ii.dbilldate >= to_char(sysdate-31,'yyyy-mm-dd')
and cu.custcode  in ('13001227192','1101b191')
and ck.storcode not in ('156','147')
and ck.storcode in ('086','084','087','154','07603','07602')
) m
group by 
库房编码
,存货编码
,订单号
)
group by
存货编码



select 存货编码 
,sum(北京慧采库存)北京慧采库存
,sum(北京云仓库存)北京云仓库存
,sum(南京慧采库存)南京慧采库存
,sum(南京云仓库存)南京云仓库存
,sum(中山慧采库存)中山慧采库存
,sum(中山云仓库存)中山云仓库存
,sum(结存数量) 合并库存
from 
(select
dd.storcode   库房编码,
bb.invcode   存货编码,
case when dd.storcode = '086' then dd.nonhandnum else 0 end 北京慧采库存
,case when dd.storcode = '084' then dd.nonhandnum else 0 end 北京云仓库存
,case when dd.storcode = '087' then dd.nonhandnum else 0 end 南京慧采库存
,case when dd.storcode = '154' then dd.nonhandnum else 0 end 南京云仓库存
,case when dd.storcode = '07603' then dd.nonhandnum else 0 end 中山慧采库存
,case when dd.storcode = '07602' then dd.nonhandnum else 0 end 中山云仓库存
,dd.nonhandnum   结存数量
from nc5x.bd_invbasdoc bb
join (select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc , cc.storname,cc.storcode
from nc5x.ic_onhandnum aa
join nc5x.bd_stordoc cc
on aa.cwarehouseid = cc.pk_stordoc) dd
on dd.cinvbasid = bb.pk_invbasdoc
join (select ee.pk_invmandoc , ff.cinventoryid ,ee.pk_invbasdoc,ff.nabprice，ff.caccountmonth,ff.noutmny,ff.noutnum
from nc5x.bd_invmandoc ee
join nc5x.ia_generalledger ff
on ee.pk_invmandoc=ff.cinventoryid  and ff.dr=0) gg
on gg.pk_invbasdoc=bb.pk_invbasdoc
where dd.nonhandnum<>0
and gg.caccountmonth<>'00'
and substr(bb.invcode,1,2) <>'98'
and storcode in ('086','084','087','154','07603','07602')) m 
group by 存货编码





