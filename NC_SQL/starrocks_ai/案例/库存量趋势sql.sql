select 
cg.invpinpai as Æ·ÅÆ,
js.dbdate,
cg.length,
sum(js.jcprice*js.nonhandnum),
sum(js.nonhandnum)
from nc5x.story_num js
join (select ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,cg.pk_invmandoc
        from nc5x.bd_invmandoc cg
        join nc5x.bd_invbasdoc ch
        on cg.pk_invbasdoc = ch.pk_invbasdoc)cg
on js.cinventoryid = cg.pk_invmandoc
join nc5x.bd_stordoc cc
on cc.pk_stordoc=js.cwarehouseid
where js.dbdate>='20201031'
and js.dbdate<='20201231'and cg.width ='¼æÈİ'--and cg.length ='Îø¹Ä'
group by cg.width,cg.invpinpai,js.dbdate,cg.length
