import { Card, Statistic, Typography } from 'antd'

import type { SummaryMetric } from '../types/api'

const { Text } = Typography

interface MetricCardProps {
  metric: SummaryMetric
}

export function MetricCard({ metric }: MetricCardProps) {
  return (
    <Card>
      <Statistic title={metric.label} value={metric.value} />
      {metric.hint ? <Text type="secondary">{metric.hint}</Text> : null}
    </Card>
  )
}
