import { Card, Col, List, Row, Table, Tag } from 'antd'

import type { RoleDiffReport } from '../types/api'

interface RoleDiffViewProps {
  report: RoleDiffReport
}

export function RoleDiffView({ report }: RoleDiffViewProps) {
  return (
    <Row gutter={[16, 16]}>
      <Col xs={24}>
        <Card title="现状角色约束违规">
          <Table
            rowKey={(record) => `${record.target_name}-${record.issue_type}-${record.detail}`}
            dataSource={report.current_role_constraint_issues}
            pagination={false}
            locale={{ emptyText: '现状角色未发现父子依赖或 SoD 违规。' }}
            columns={[
              { title: '现状角色', dataIndex: 'target_name', key: 'target_name' },
              {
                title: '级别',
                dataIndex: 'severity',
                key: 'severity',
                render: (value: 'hard' | 'soft' | 'warning') => (
                  <Tag color={value === 'hard' ? 'red' : value === 'soft' ? 'orange' : 'gold'}>{value}</Tag>
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
      <Col xs={24}>
        <Card title="现状角色摘要">
          <Table
            rowKey="role_id"
            dataSource={report.current_roles}
            pagination={false}
            columns={[
              { title: '现状角色', dataIndex: 'role_name', key: 'role_name' },
              { title: '权限数', dataIndex: 'permission_count', key: 'permission_count' },
              { title: '用户数', dataIndex: 'user_count', key: 'user_count' },
              {
                title: '权限明细',
                key: 'permission_names',
                render: (_, record) => record.permission_names.map((item) => <Tag key={item}>{item}</Tag>),
              },
            ]}
          />
        </Card>
      </Col>
      <Col xs={24}>
        <Card title="推荐角色与现状角色对比">
          <Table
            rowKey={(record) => `${record.recommended_unit_name}-${record.current_role_name ?? 'new'}`}
            dataSource={report.comparisons}
            pagination={false}
            columns={[
              { title: '推荐角色', dataIndex: 'recommended_unit_name', key: 'recommended_unit_name' },
              {
                title: '最接近现状角色',
                dataIndex: 'current_role_name',
                key: 'current_role_name',
                render: (value) => value ?? <Tag color="blue">建议新增</Tag>,
              },
              {
                title: '重叠度',
                dataIndex: 'overlap_rate',
                key: 'overlap_rate',
                render: (value: number) => `${(value * 100).toFixed(1)}%`,
              },
              {
                title: '推荐新增权限',
                key: 'recommended_only_permissions',
                render: (_, record) =>
                  record.recommended_only_permissions.length
                    ? record.recommended_only_permissions.map((item) => <Tag color="green" key={item}>{item}</Tag>)
                    : '-',
              },
              {
                title: '现状冗余权限',
                key: 'current_only_permissions',
                render: (_, record) =>
                  record.current_only_permissions.length
                    ? record.current_only_permissions.map((item) => <Tag color="orange" key={item}>{item}</Tag>)
                    : '-',
              },
              { title: '建议动作', dataIndex: 'action', key: 'action' },
            ]}
          />
        </Card>
      </Col>
      <Col xs={24} lg={12}>
        <Card title="推荐角色的现状组合映射">
          <Table
            rowKey={(record) => `${record.recommended_unit_name}-${record.current_role_names.join('-')}`}
            dataSource={report.combination_mappings}
            pagination={false}
            columns={[
              { title: '推荐角色', dataIndex: 'recommended_unit_name', key: 'recommended_unit_name' },
              {
                title: '现状角色组合',
                key: 'current_role_names',
                render: (_, record) => record.current_role_names.map((item) => <Tag key={item}>{item}</Tag>),
              },
              {
                title: '覆盖率',
                dataIndex: 'coverage_rate',
                key: 'coverage_rate',
                render: (value: number) => `${(value * 100).toFixed(1)}%`,
              },
              {
                title: '缺失权限',
                key: 'missing_permissions',
                render: (_, record) =>
                  record.missing_permissions.length
                    ? record.missing_permissions.map((item) => <Tag color="red" key={item}>{item}</Tag>)
                    : <Tag color="green">无缺失</Tag>,
              },
              {
                title: '额外权限',
                key: 'extra_permissions',
                render: (_, record) =>
                  record.extra_permissions.length
                    ? record.extra_permissions.map((item) => <Tag color="orange" key={item}>{item}</Tag>)
                    : <Tag color="green">无额外</Tag>,
              },
              { title: '建议动作', dataIndex: 'action', key: 'action' },
            ]}
          />
        </Card>
      </Col>
      <Col xs={24} lg={12}>
        <Card title="现状角色合并建议">
          <Table
            rowKey={(record) => record.role_names.join('-')}
            dataSource={report.merge_suggestions}
            pagination={false}
            columns={[
              {
                title: '候选合并角色',
                key: 'role_names',
                render: (_, record) => record.role_names.map((item) => <Tag key={item}>{item}</Tag>),
              },
              {
                title: '重叠度',
                dataIndex: 'overlap_rate',
                key: 'overlap_rate',
                render: (value: number) => `${(value * 100).toFixed(1)}%`,
              },
              {
                title: '共享权限',
                key: 'shared_permissions',
                render: (_, record) => record.shared_permissions.map((item) => <Tag key={item}>{item}</Tag>),
              },
              { title: '建议动作', dataIndex: 'action', key: 'action' },
            ]}
            locale={{ emptyText: '当前没有明显的高重叠现状角色。' }}
          />
        </Card>
      </Col>
      <Col xs={24} lg={12}>
        <Card title="现状角色处理建议">
          <List
            dataSource={report.current_role_actions}
            locale={{ emptyText: '现状角色均已找到较合适的推荐映射。' }}
            renderItem={(item) => <List.Item>{item}</List.Item>}
          />
        </Card>
      </Col>
      <Col xs={24} lg={12}>
        <Card title="建议下线角色与差异摘要">
          <List
            dataSource={report.current_roles_to_retire}
            locale={{ emptyText: '当前没有建议直接下线的现状角色。' }}
            renderItem={(item) => <List.Item>{`建议评估下线：${item}`}</List.Item>}
          />
          <List
            dataSource={report.summary}
            renderItem={(item) => <List.Item>{`${item.label}: ${item.value}`}</List.Item>}
          />
        </Card>
      </Col>
    </Row>
  )
}
