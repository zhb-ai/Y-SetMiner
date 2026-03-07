import { Table, Tag } from 'antd'

import type { SolutionUnit } from '../types/api'

interface UnitsTableProps {
  units: SolutionUnit[]
}

export function UnitsTable({ units }: UnitsTableProps) {
  return (
    <Table
      rowKey="id"
      dataSource={units}
      pagination={false}
      columns={[
        {
          title: '名称',
          dataIndex: 'name',
          key: 'name',
        },
        {
          title: '字段/权限',
          key: 'items',
          render: (_, record) => record.item_names.map((item) => <Tag key={item}>{item}</Tag>),
        },
        {
          title: '覆盖对象',
          key: 'entities',
          render: (_, record) => record.covered_entity_names.join('、'),
        },
        {
          title: '来源',
          key: 'sources',
          render: (_, record) =>
            record.sources.length ? record.sources.map((source) => <Tag key={source}>{source}</Tag>) : '-',
        },
        {
          title: '得分',
          dataIndex: 'score',
          key: 'score',
        },
        {
          title: '推荐理由',
          dataIndex: 'rationale',
          key: 'rationale',
        },
      ]}
    />
  )
}
