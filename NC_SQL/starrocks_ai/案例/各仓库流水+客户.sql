select 
--d.客户名称
d.存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
d.数量,
d.流水,
d.仓库,
d.排名
from  (select d.存货编码,d.存货名称,d.仓库 ,sum(d.数量) 数量,sum(d.流水) 流水,dense_rank()OVER(PARTITION BY d.仓库,d.存货编码
        ORDER BY sum(d.流水) desc ) AS  排名  from (select 
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
cu.custname as 客户名称,
bc.storname as 仓库,
ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) AS 流水,
js.nnewbalancenum as 数量
from nc5x.so_squaredetail js
LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
on js.cinventoryid = cg.pk_invmandoc
LEFT join nc5x.bd_busitype yw
on js.cbiztype = yw.pk_busitype
LEFT join nc5x.v_zlw_cust cu
on js.ccustomerid = cu.pk_cumandoc 
left outer join nc5x.bd_stordoc bc
on bc.pk_corp = js.pk_corp
where js.dmakedate >= '2019-10-01'
  and js.dmakedate <= '2019-12-31'
  and cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and js.dr=0
  and yw.busicode <> 's005'
  and '流水' <> 'null'
  and bc.storname in ('成都本部',
'哈尔滨本部',
'科捷仓-北京朝阳',                              
'南京本部',
'沈阳东贸库',
'西安本部',
'重庆本部','一号库') 
  and cg.width='兼容'
  )d group by d.存货编码,d.存货名称,d.仓库
  ) d  LEFT join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
        on d.存货编码=cg.invcode 
 
