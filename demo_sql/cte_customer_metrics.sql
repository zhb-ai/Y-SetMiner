with paid_orders as (
  select
    o.customer_id,
    o.order_id,
    o.amount,
    o.order_date
  from t_order o
  where o.pay_status = 'paid'
),
customer_metrics as (
  select
    po.customer_id,
    count(distinct po.order_id) as paid_order_count,
    sum(po.amount) as paid_amount
  from paid_orders po
  group by po.customer_id
)
select
  cm.customer_id,
  c.customer_name,
  cm.paid_order_count,
  cm.paid_amount,
  cm.paid_amount / nullif(cm.paid_order_count, 0) as avg_paid_amount
from customer_metrics cm
left join t_customer c
  on cm.customer_id = c.customer_id;
