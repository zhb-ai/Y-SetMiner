
select zz.*,ma.*,mm.*
 from
 (select 
aa.pk_invbasdoc as 主键,
aa.invcode as 存货编码,
aa.invname  as 存货名称,
aa.def10 as 供应商,
aa.def2 as 装箱数,
case when aa.def8 not like '%不备货%' then '不备货' else '备货' end 是否备货,
aa.invpinpai   as 品牌 ,
aa.width    as 大类 ,
aa.length    as 品类 ,
aa.height   as 小类 
 from nc5x.bd_invbasdoc aa 
join nc5x.bd_invmandoc bb 
on aa.pk_invbasdoc = bb.pk_invbasdoc  
where   
 bb.sealflag  ='N'and aa.width  ='兼容'
) zz left join 
(
select ib.cinvbasdocid as  主键 ,
sum(case when ck.storname  in ('1号库') then ib.nnumber else 0 end ) 北京销量,
sum(case when ck.storname  in ('成都本部','成都门市') then ib.nnumber else 0 end ) 成都销量,
sum(case when ck.storname  in ('重庆本部','重庆泰兴') then ib.nnumber else 0 end ) 重庆销量,
sum(case when ck.storname  in ('沈阳本部','沈 阳数码') then ib.nnumber else 0 end ) 沈阳销量,
sum(case when ck.storname  in ('哈尔滨本部','哈尔滨教化') then ib.nnumber else 0 end ) 哈尔滨销量,
sum(case when ck.storname  in ('西安本部','西安科贸') then ib.nnumber else 0 end ) 西安销量,
sum(case when ck.storname  in ('南京本部','南 京雄狮') then ib.nnumber else 0 end ) 南京销量,
sum(case when ck.storname  in ('中山仓') then ib.nnumber else 0 end ) 中山销量
from nc5x.so_saleinvoice ii
join (select ib.cinvbasdocid, ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode
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
where 
ii.dbilldate >= to_char(sysdate - 31,'yyyy-mm-dd')   
and ii.dr=0 
and ib.width  in ('兼容') and ck.storname in ('1号库','成都本部','成都门市','重庆本部','重庆泰兴','沈阳本部','沈 阳数码','哈尔滨本部','哈尔滨教化','西安本部','西安科贸','南京本部','南 京雄狮','中山仓' )
group by ib.cinvbasdocid 
)ma on zz.主键= ma.主键
left join 
(select
bb.pk_invbasdoc  主键,
SUM(dd.nonhandnum)   结存数量 ,
sum(case when dd.storname  in ('1号库') then dd.nonhandnum else 0 end) 北京库存,
sum(case when dd.storname  in ('成都本部','成都门市') then dd.nonhandnum else 0 end) 成都库存,
sum(case when dd.storname  in ('重庆本部','重庆泰兴') then dd.nonhandnum else 0 end) 重庆库存,
sum(case when dd.storname  in ('沈阳本部','沈 阳数码') then dd.nonhandnum else 0 end) 沈阳库存,
sum(case when dd.storname  in ('哈尔滨本部','哈尔滨教化') then dd.nonhandnum else 0 end) 哈尔滨库存,
sum(case when dd.storname  in ('西安本部','西安科贸') then dd.nonhandnum else 0 end) 西安库存,
sum(case when dd.storname  in ('南京本部','南 京雄狮') then dd.nonhandnum else 0 end) 南京库存,
sum(case when dd.storname  in ('中山仓') then dd.nonhandnum else 0 end) 中山库存
from nc5x.bd_invbasdoc bb
join (select aa.cinvbasid , aa.cwarehouseid, aa.nonhandnum,cc.pk_stordoc,cc.storname
      from nc5x.ic_onhandnum aa
      join nc5x.bd_stordoc cc
      on aa.cwarehouseid = cc.pk_stordoc ) dd
on dd.cinvbasid = bb.pk_invbasdoc
where dd.nonhandnum<>0 and dd.storname in ('1号库','成都本部','成都门市','重庆本部','重庆泰兴','沈阳本部','沈 阳数码','哈尔滨本部','哈尔滨教化','西安本部','西安科贸','南京本部','南 京雄狮','中山仓')
GROUP BY bb.pk_invbasdoc order by 1 asc
) mm
on zz.主键 = mm.主键
