import { Table, Tag } from 'antd'

import type { Assignment } from '../types/api'

interface AssignmentsTableProps {
  assignments: Assignment[]
}

export function AssignmentsTable({ assignments }: AssignmentsTableProps) {
  return (
    <Table
      rowKey="entity_id"
      dataSource={assignments}
      pagination={false}
      columns={[
        {
          title: '对象',
          dataIndex: 'entity_name',
          key: 'entity_name',
        },
        {
          title: '推荐组合',
          key: 'units',
          render: (_, record) => record.unit_names.map((unit) => <Tag key={unit}>{unit}</Tag>),
        },
        {
          title: '未覆盖项',
          key: 'uncovered',
          render: (_, record) =>
            record.uncovered_item_names.length
              ? record.uncovered_item_names.map((item) => <Tag color="orange" key={item}>{item}</Tag>)
              : <Tag color="green">已覆盖</Tag>,
        },
      ]}
    />
  )
}
