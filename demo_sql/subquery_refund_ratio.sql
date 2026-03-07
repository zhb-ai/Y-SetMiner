select
  base.customer_id,
  base.customer_name,
  base.order_amount,
  base.refund_amount,
  base.refund_amount / nullif(base.order_amount, 0) as refund_ratio
from (
  select
    c.customer_id,
    c.customer_name,
    sum(o.amount) as order_amount,
    sum(coalesce(r.refund_amount, 0)) as refund_amount
  from t_customer c
  left join t_order o
    on c.customer_id = o.customer_id
  left join t_refund r
    on o.order_id = r.order_id
  group by c.customer_id, c.customer_name
) base;
