select
  o.order_id,
  o.order_date,
  o.customer_id,
  c.customer_name,
  o.amount
from t_order o
left join t_customer c
  on o.customer_id = c.customer_id;
