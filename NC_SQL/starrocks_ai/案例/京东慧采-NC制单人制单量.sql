

select 
distinct 
m.vreceiptcode  as 外部单号,
ii.dbilldate as 日期,
 w.user_name as 制单人,
 cu.deptname as 市场部,
 m.vdef8 as 服务商,
cu.n_deptname as 部门,
cu.custname as 客户名称,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员
  from nc5x.so_saleinvoice ii
 left  join (select ib.csaleid,ib.nnumber,ib.nsummny,ch.invpinpai,ch.height,ch.width,ch.length,ch.invname,ch.invcode,ib.blargessflag ,ch.pk_invbasdoc,ib.coriginalbillcode, ib.noriginalcurmny,
  ch.unitvolume ,
ch.unitweight 
          from nc5x.so_saleinvoice_b ib
          join nc5x.bd_invbasdoc ch
            on ib.cinvbasdocid = ch.pk_invbasdoc
             ) ib
    on ib.csaleid = ii.csaleid
  left join nc5x.v_zlw_cust cu 
    on ii.creceiptcorpid  = cu.pk_cumandoc
    LEFT join nc5x.bd_busitype  yw
on ii.cbiztype = yw.pk_busitype
     left join nc5x.bd_stordoc dd
    on ii.cwarehouseid = dd.pk_stordoc
     left  join  nc5x.so_sale m 
on ib.coriginalbillcode =m.vreceiptcode
left join nc5x.sm_user w
  on m.coperatorid =w.cuserid
left join nc5x.bd_psndoc  us
on us.pk_psndoc= ii.cemployeeid
where (1=1)  
and length(ib.invcode) > 4 
and  ii.dr = 0 
and m.vreceiptcode in 
(select distinct hs.vreceiptcode 
from nc5x.so_squaredetail js 
join nc5x.so_sale  hs 
 on js.csourcebillid   =hs.csaleid where  js.dr=0 and (case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end ) between '2022-07-01' and '2022-07-31' and 
 (CASE WHEN cu.psnname is null then us.psnname else cu.psnname end)  in ('孙希宝','张学兵','刘鱼浩')
 )
