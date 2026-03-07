from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from app.schemas.solve import SceneDataset


@dataclass
class MatrixBundle:
    matrix: np.ndarray
    entity_ids: list[str]
    entity_names: list[str]
    item_ids: list[str]
    item_names: list[str]


def build_matrix(dataset: SceneDataset) -> MatrixBundle:
    entity_ids = [entity.id for entity in dataset.entities]
    entity_names = [entity.name for entity in dataset.entities]
    item_ids = [item.id for item in dataset.items]
    item_names = [item.name for item in dataset.items]

    entity_index = {entity_id: idx for idx, entity_id in enumerate(entity_ids)}
    item_index = {item_id: idx for idx, item_id in enumerate(item_ids)}
    matrix = np.zeros((len(entity_ids), len(item_ids)), dtype=int)

    for relation in dataset.relations:
        row = entity_index.get(relation.entity_id)
        col = item_index.get(relation.item_id)
        if row is not None and col is not None:
            matrix[row, col] = 1

    return MatrixBundle(
        matrix=matrix,
        entity_ids=entity_ids,
        entity_names=entity_names,
        item_ids=item_ids,
        item_names=item_names,
    )
