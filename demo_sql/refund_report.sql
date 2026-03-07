select
  o.order_id,
  o.order_date,
  r.refund_amount,
  c.customer_name
from t_refund r
left join t_order o
  on r.order_id = o.order_id
left join t_customer c
  on o.customer_id = c.customer_id;
