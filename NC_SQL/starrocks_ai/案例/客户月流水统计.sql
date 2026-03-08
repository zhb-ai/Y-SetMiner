select ma.客户名称,ma.品牌,ma.是否赠品,ma.月份,ma.品牌一,sum(ma.数量),sum(ma.流水) from   (
select ma.客户名称,ma.存货编码,ma.存货名称--,ma.单据号
,ma.大类,ma.品类,ma.品牌,ma.小类,ma.数量,ma.是否赠品,ma.市场部,ma.部门,ma.业务员,to_date(ma.日期,'yyyy-MM-dd') as 日期,ma.流水,ma.毛利,ma.省,ma.市,case when substr(ma.日期,6,2)='01' then '1月'
 when substr(ma.日期,6,2)='02' then '2月'
    when substr(ma.日期,6,2)='03' then '3月'
       when substr(ma.日期,6,2)='04' then '4月'  
          when substr(ma.日期,6,2)='05' then '5月'
           when substr(ma.日期,6,2)='06' then '6月'
              when substr(ma.日期,6,2)='07' then '7月'
                 when substr(ma.日期,6,2)='08' then '8月'
                    when substr(ma.日期,6,2)='09' then '9月'  
                       when substr(ma.日期,6,2)='10' then '10月'
                          when substr(ma.日期,6,2)='11' then '11月'
                             when substr(ma.日期,6,2)='12' then '12月' end 月份,
          case when substr(ma.日期,1,4)='2019'  then '2019'
           when substr(ma.日期,1,4)='2020'  then '2020' end 年份,
            case when ma.品牌 like '%扬帆耐立%'or ma.品牌 like '%盈佳%' then '高端'
              when ma.品牌 like '%智通%'then '中高'
                when ma.品牌 like '%懿%' or  ma.品牌 like '%方格%' then '中低' end 品牌分级,
                 
            case when ma.品牌 like '%扬帆耐立%'or ma.品牌 like '%盈佳%'or  ma.品牌 like '%智通%'or  ma.品牌 like '%方格%' then '线上'
         
                when ma.品牌 like '%懿智通%'  then '代理商'
                   when ma.品牌 like '%懿品%'  then '线下' 
                  end 渠道,
                  case when ma.品牌 like '%扬帆耐立%' then '扬帆耐立'
                  when  ma.品牌 like '%盈佳%'then '盈佳' 
                   when   ma.品牌 like '智通%'then  '智通'
                      when   ma.品牌 like '%方格%' then '方格博士'
         
                when ma.品牌 like '%懿智通%'  then '懿智通'
                   when ma.品牌 ='懿品'  then '懿品' 
                       when ma.品牌 like '%懿品佳%'then '懿品佳' 
                  end 品牌一
                  
from ( select 
cu.custname as 客户名称,
cg.invcode as 存货编码,
cg.invname as 存货名称,
cg.width as 大类,
cg.length as 品类,
cg.invpinpai as 品牌,
cg.height as 小类,
js.nnewbalancenum as 数量,
js.blargessflag as 是否赠品,
--d.coriginalbillcode 单据号,
cu.deptname as 市场部,
cu.n_deptname as 部门,
(CASE WHEN cu.psnname is null then us.psnname else cu.psnname end) as 业务员,
(case when js.dapprovedate is null then js.dmakedate else js.dapprovedate end )as 日期,
 js.vdef11 as 业务属性,
  js.nsummny  as 本币价税合计,
  js.nnewbalancenum*js.vbodydef5 as 批发价税合计,
  (CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny  ELSE js.nnewbalancenum*js.vbodydef5 END) AS 价税合计,
  ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2) AS 流水,
  ROUND((CASE WHEN TO_NUMBER(js.nnewbalancenum*js.vbodydef5)=0 OR js.nnewbalancenum*js.vbodydef5 IS NULL THEN js.nsummny ELSE js.nnewbalancenum*js.vbodydef5 END)/(js.NTAXRATE*0.01+1),2)-js.ncostmny AS 毛利,
  js.ncostmny as 成本,cu.sf as 省,
cu.cs as 市 
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
left join nc5x.bd_psndoc us
on us.pk_psndoc= js.cemployeeid
left join 
(SELECT distinct coriginalbillcode idd ,csourcebillbodyid  FROM NC5X.so_saleinvoice_b )d
on js.vreceiptcode=d.csourcebillbodyid
where            
  cg.invcode <> '9805'
  and cg.invcode <> '9810'
  and cg.invcode <> '9807'
  and cg.invcode <> '9809'
  and cg.invcode <> '9899'
  and yw.busicode <> 's005'
  and js.dr=0
  and '流水' <> 'null' 
  )ma
where  --and ma.存货名称 LIKE '%921%'
 SUBSTR(ma.日期,1,10) between  '2020-01-01'and '2020-06-30')ma  group by ma.客户名称,ma.品牌,ma.是否赠品,ma.月份,ma.品牌一 having   ma.客户名称 in ('垣曲县佳信电子科技有限公司',
'青岛骄阳电子科技有限公司',
'三河豪达贸易有限公司',
'山东佳和电子信息有限公司',
'枣庄市恒拓电子有限公司',
'欧菲斯办公伙伴重庆有限公司',
'蔚县倬馨商贸有限公司',
'乌鲁木齐市创信辉鸿电子科技有限责任公司',
'阳泉联合伟创商贸有限公司',
'贵州科利文贸易有限公司',
'白山市大元科技有限公司',
'四川博海云天科技有限公司',
'通辽市华诚商贸有限公司',
'沈阳华宇欣办公用品有限公司',
'沈阳惠康商贸有限公司',
'阜新市金诚科贸电子有限公司',
'辽阳欧菲斯办公伙伴商贸有限公司',
'石家庄宝玲商贸有限公司',
'武威弘雅计算机科技有限公司',
'鄂尔多斯市鑫海商贸有限公司',
'山西金创伟商贸有限公司',
'河南丰景浩呈电子科技有限公司',
'沈阳华米贸易有限公司',
'锦州思达商贸有限公司',
'北镇市晨光商贸有限公司',
'辽宁大唐电子有限公司',
'长春市新洪翔商贸有限公司',
'凌源市辰阳商贸有限公司',
'成都皓天科技有限公司崇州分公司',
'绵阳市领先未来科技有限公司',
'宜宾风行电子有限公司',
'西藏西图商贸有限公司',
'宣汉县众汇科技电脑经营部',
'达州市乐创信息科技有限公司',
'锡林郭勒盟鑫明星办公设备有限责任公司',
'呼和浩特市德强电脑公司',
'衡水友邦办公设备商贸有限公司',
'龙口市阳光数码商务中心',
'烟台金汇联网络科技有限公司',
'铁岭市银州区拓达商贸有限公司',
'北票仕达办公用品销售有限公司',
'梅河口市科航智诚科技有限公司',
'榆林市星光伟业商贸有限公司',
'府谷县新维德文体办公有限公司',
'宝应县中择电子科技有限公司',
'农安县农安镇华兴办公用品商店',
'兴隆台区惊鸣电脑商行',
'苏州申合信电子商务有限公司',
'青海俊梵商贸有限公司',
'五原县宏美网络有限责任公司',
'大同市同方万维电器维护有限公司',
'迁安市锐达兴业商贸有限公司',
'承德瑞天商贸有限公司',
'包头市普拓商贸有限公司',
'南皮县程前科技服务中心',
'任丘市华联计算机有限公司',
'盐城市世隆电脑有限公司',
'宜兴市佳乐电脑有限公司',
'靖江华翱智能网络科技有限公司',
'连云港日佰斗商贸有限公司',
'阿巴嘎旗千凯电脑耗材经销部',
'东营市众力实业有限责任公司',
'佳木斯龙华恒业电子科技有限公司',
'望奎龙腾电子有限公司',
'甘肃承创商贸有限责任公司',
'咸宁市金正商贸有限公司',
'咸阳翔顺电子科技有限公司',
'延安市宝塔区绍恒商贸有限公司',
'泸州市捷诚办公设备有限公司',
'宁波市海曙博林电脑有限公司',
'昆山鹏莱信息科技有限公司',
'菏泽市赛通数码科技有限公司',
'东海县晶城时代家用电器销售有限公司',
'连云港磊天贸易有限公司',
'淮安纳斯特网络科技有限公司',
'连云港市得能办公用品有限公司')--and (ma.品牌 like '%扬帆耐立%'or ma.品牌 like '%盈佳%')and ma.存货名称 like '%CE74%'

