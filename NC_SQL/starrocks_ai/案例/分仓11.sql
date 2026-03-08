SELECT
  * 
FROM
  (
  SELECT
    ma.*,
    nvl (
    CASE
        
        WHEN regexp_like ( ma.客户分布, '(甘肃|宁夏|青海|陕西|新疆)' ) THEN
        '西安' 
        WHEN regexp_like ( ma.客户分布, '(吉林|辽宁)' ) THEN
        '沈阳' 
        WHEN regexp_like ( ma.客户分布, '(安徽|广西|湖北|湖南|江苏|上海|浙江|江西|福建|广东|海南)' ) THEN
        '南京' 
        WHEN regexp_like ( ma.客户分布, '(黑龙江)' ) THEN
        '哈尔滨' 
        WHEN regexp_like ( ma.客户分布, '(贵州|四川|西藏|云南|重庆)' ) THEN
        '成都' 
        WHEN regexp_like ( ma.客户分布, '(北京|河北|河南|内蒙古|山东|山西|天津)' ) THEN
        '北京' 
      END, 客户分布 
  ) AS 客户分 
  ,
CASE
    
    WHEN ma.出库仓库 LIKE '%1号%' THEN
    '北京' 
    WHEN ma.出库仓库 LIKE '%沈%' THEN
    '沈阳' 
    WHEN ma.出库仓库 LIKE '%重%' THEN
    '重庆' 
    WHEN ma.出库仓库 LIKE '%西%' THEN
    '西安' 
    WHEN ma.出库仓库 LIKE '%南%' THEN
    '南京' 
    WHEN ma.出库仓库 LIKE '%哈%' THEN
    '哈尔滨' 
    WHEN ma.出库仓库 LIKE '%都%' THEN
    '成都'
    WHEN ma.出库仓库 LIKE '%中山%' THEN
    '中山'
     ELSE '其他' 
  END 库房分布 
FROM
  (
  SELECT
    p.vreceiptcode 单据号 ,
    decode ( p.fstatus, 6, '结束', 1, '自由', 2, '审核', p.fstatus ) 单据状态 ,
    rc.storname 出库仓库,
    m.cinvbasdocid 存货档案主键,
    p.vnote 收货地址 ,
    p.vdef20 备注,
    ch.invcode 存货编码,
    ch.invname 存货名称,
    ch.height 小类 ,
    ch.width 大类,
    ch.length 原装,
    p.dbilldate 日期,
    cu.deptname AS 市场部,
    cu.n_deptname AS 部门,
    cu.psnname AS 业务员,
    cu.pk_cumandoc AS 客户主键,
    m.nnumber AS 数量,
  CASE
      
      WHEN regexp_like ( substr ( p.vdef20, 1, 8 ), '(甘肃|宁夏|青海|陕西|新疆)' ) THEN
      '西安' 
      WHEN regexp_like ( substr ( p.vdef20, 1, 8 ), '(吉林|辽宁)' ) THEN
      '沈阳' 
      WHEN regexp_like ( substr ( p.vdef20, 1, 8 ), '(安徽|广西|湖北|湖南|江苏|上海|浙江|江西|福建|广东|海南)' ) THEN
      '南京' 
      WHEN regexp_like ( substr ( p.vdef20, 1, 8 ), '(黑龙江)' ) THEN
      '哈尔滨' 
      WHEN regexp_like ( substr ( p.vdef20, 1, 8 ), '(贵州|四川|西藏|云南|重庆)' ) THEN
      '成都' 
      WHEN regexp_like ( substr ( p.vdef20, 1, 8 ), '(北京|河北|河南|内蒙古|山东|山西|天津)' ) 
      OR cu.sf IS NULL THEN
        '北京' ELSE cu.sf 
      END 客户分布 
FROM
  nc5x.so_sale p
  LEFT JOIN nc5x.so_saleorder_b m ON p.csaleid= m.csaleid
  LEFT JOIN nc5x.Bd_Stordoc rc ON m.cbodywarehouseid= rc.pk_stordoc
  JOIN nc5x.bd_invbasdoc ch ON m.cinvbasdocid = ch.pk_invbasdoc
  LEFT JOIN nc5x.v_zlw_cust cu ON p.ccustomerid  = cu.pk_cumandoc 
WHERE
  ( 1 = 1 ) 
  AND p.dr= 0 
  AND p.dbilldate  = to_char ( sysdate, 'yyyy-mm-dd' ) 
  and  ch.width  ='兼容'
  ) ma 
  ) ma where ma.客户分 <> ma.库房分布
