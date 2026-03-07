from fastapi import APIRouter, File, Form, UploadFile

from app.schemas.solve import ImportPreviewResponse, SceneInfo, SolveRequest, SolveResponse
from app.services.algorithms.set_miner import SetMinerService
from app.services.scenes.erp_importer import ErpImportService
from app.services.scenes.demo_data import SCENES, get_demo_dataset
from app.services.scenes.sql_importer import SqlImportService

router = APIRouter()
solver = SetMinerService()
erp_importer = ErpImportService()
sql_importer = SqlImportService()


@router.get("/health")
def healthcheck() -> dict[str, str]:
    return {"status": "ok", "service": "setminer-api"}


@router.get("/scenes", response_model=list[SceneInfo])
def list_scenes() -> list[SceneInfo]:
    return SCENES


@router.get("/scenes/{scene_key}/demo", response_model=SolveResponse)
def solve_demo(scene_key: str) -> SolveResponse:
    dataset = get_demo_dataset(scene_key)
    return solver.solve(dataset)


@router.post("/jobs/solve", response_model=SolveResponse)
def solve_job(payload: SolveRequest) -> SolveResponse:
    dataset = payload.dataset or get_demo_dataset(payload.scene)
    return solver.solve(dataset)


@router.post("/import/erp/users-permissions/preview", response_model=ImportPreviewResponse)
async def preview_erp_users_permissions(file: UploadFile = File(...)) -> ImportPreviewResponse:
    return await erp_importer.preview_upload(file)


@router.post("/import/erp/users-permissions/solve", response_model=SolveResponse)
async def solve_erp_users_permissions(
    file: UploadFile = File(...),
    current_role_permissions_file: UploadFile | None = File(default=None),
    current_user_roles_file: UploadFile | None = File(default=None),
) -> SolveResponse:
    dataset = await erp_importer.solve_upload(file)
    current_role_state = await erp_importer.parse_current_roles(
        current_role_permissions_file=current_role_permissions_file,
        current_user_roles_file=current_user_roles_file,
    )
    return solver.solve(dataset, current_role_state=current_role_state)


@router.post("/import/sql/documents/preview", response_model=ImportPreviewResponse)
async def preview_sql_documents(
    files: list[UploadFile] = File(...),
    base_field_threshold: float = Form(0.6),
    suggested_field_threshold: float = Form(0.45),
) -> ImportPreviewResponse:
    return await sql_importer.preview_uploads(
        files,
        base_field_threshold=base_field_threshold,
        suggested_field_threshold=suggested_field_threshold,
    )


@router.post("/import/sql/documents/solve", response_model=SolveResponse)
async def solve_sql_documents(
    files: list[UploadFile] = File(...),
    base_field_threshold: float = Form(0.6),
    suggested_field_threshold: float = Form(0.45),
) -> SolveResponse:
    dataset = await sql_importer.solve_uploads(
        files,
        base_field_threshold=base_field_threshold,
        suggested_field_threshold=suggested_field_threshold,
    )
    return solver.solve(dataset)
