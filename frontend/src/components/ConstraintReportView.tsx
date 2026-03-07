import { Card, Col, List, Row, Table, Tag } from 'antd'

import type { ErpConstraintReport } from '../types/api'

interface ConstraintReportViewProps {
  report: ErpConstraintReport
}

const severityColorMap = {
  hard: 'red',
  soft: 'orange',
  warning: 'gold',
} as const

export function ConstraintReportView({ report }: ConstraintReportViewProps) {
  return (
    <Row gutter={[16, 16]}>
      <Col xs={24}>
        <Card title="约束摘要">
          <List
            dataSource={report.summary}
            renderItem={(item) => <List.Item>{`${item.label}: ${item.value}`}</List.Item>}
          />
        </Card>
      </Col>
      <Col xs={24} lg={12}>
        <Card title="自动修复记录">
          <Table
            rowKey={(record) => `${record.target_name}-${record.fix_type}-${record.detail}`}
            dataSource={report.autofixes}
            pagination={false}
            locale={{ emptyText: '当前没有自动修复记录。' }}
            columns={[
              { title: '对象', dataIndex: 'target_name', key: 'target_name' },
              { title: '修复类型', dataIndex: 'fix_type', key: 'fix_type' },
              {
                title: '补齐权限',
                key: 'added_permission_names',
                render: (_, record) =>
                  record.added_permission_names.length
                    ? record.added_permission_names.map((item) => <Tag key={item}>{item}</Tag>)
                    : '-',
              },
              { title: '说明', dataIndex: 'detail', key: 'detail' },
            ]}
          />
        </Card>
      </Col>
      <Col xs={24} lg={12}>
        <Card title="约束告警与违规">
          <Table
            rowKey={(record) => `${record.target_name}-${record.issue_type}-${record.detail}`}
            dataSource={report.issues}
            pagination={false}
            locale={{ emptyText: '当前没有额外约束告警。' }}
            columns={[
              { title: '对象', dataIndex: 'target_name', key: 'target_name' },
              {
                title: '级别',
                dataIndex: 'severity',
                key: 'severity',
                render: (value: 'hard' | 'soft' | 'warning') => (
                  <Tag color={severityColorMap[value]}>{value}</Tag>
                ),
              },
              { title: '类型', dataIndex: 'issue_type', key: 'issue_type' },
              {
                title: '涉及权限',
                key: 'permission_names',
                render: (_, record) =>
                  record.permission_names.length
                    ? record.permission_names.map((item) => <Tag key={item}>{item}</Tag>)
                    : '-',
              },
              { title: '说明', dataIndex: 'detail', key: 'detail' },
            ]}
          />
        </Card>
      </Col>
    </Row>
  )
}
