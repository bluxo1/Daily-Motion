from typing import Annotated, Any
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Path, Query, Request, Response
from fastapi.openapi.utils import get_openapi
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.exc import SQLAlchemyError
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from daily_motion.accounts import current_provider_identity, initialize_account
from daily_motion.auth import bearer, verified_owner
from daily_motion.config import settings
from daily_motion.contracts import (
    BATCH_LIMIT,
    AccountInitializeRequest,
    AccountResponse,
    BootstrapManifest,
    BootstrapRequest,
    CreateSession,
    EmptyPayload,
    MeResponse,
    OperationV2,
    PullResponse,
    PushRequest,
    PushRequestV2,
    PushResponse,
    RecordSet,
    SnapshotPage,
)
from daily_motion.db import database_readiness
from daily_motion.sync import accept, bootstrap, me, pull, snapshot_page, validate_snapshot


class BodyLimit:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        # Bound the raw body before JSON parsing, including chunked requests.
        parts: list[bytes] = []
        size = 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            part = message.get("body", b"")
            size += len(part)
            if size > BATCH_LIMIT:
                await Response(
                    '{"detail":{"code":"body_too_large"}}',
                    status_code=413,
                    media_type="application/json",
                )(scope, receive, send)
                return
            parts.append(part)
            if not message.get("more_body", False):
                break
        consumed = False

        async def bounded_receive() -> Message:
            nonlocal consumed
            if not consumed:
                consumed = True
                return {"type": "http.request", "body": b"".join(parts), "more_body": False}
            return await receive()

        await self.app(scope, bounded_receive, send)


app = FastAPI(title="Daily Motion foundation API", version="0.1.0")
app.add_middleware(BodyLimit)
Owner = Annotated[UUID, Depends(verified_owner)]


@app.exception_handler(SQLAlchemyError)
def database_unavailable(request: Request, error: SQLAlchemyError) -> JSONResponse:
    # SQLAlchemy exception strings can contain credentials, SQL parameters and
    # private workout payloads. Do not stringify/log or return the exception.
    return JSONResponse(
        status_code=503,
        content={"detail": {"code": "database_unavailable"}},
        headers={"Cache-Control": "private, no-store"},
    )


def sync_openapi() -> dict[str, Any]:
    if app.openapi_schema is None:
        schema = get_openapi(title=app.title, version=app.version, routes=app.routes)
        components = schema["components"]["schemas"]
        # Describe command-specific payloads while keeping raw receipt/echo bytes.
        for model in (CreateSession, RecordSet, EmptyPayload, OperationV2, PushRequestV2):
            definition = model.model_json_schema(ref_template="#/components/schemas/{model}")
            components.update(definition.pop("$defs", {}))
            components[model.__name__] = definition
        app.openapi_schema = schema
    return app.openapi_schema


app.openapi = sync_openapi  # type: ignore[method-assign]


@app.middleware("http")
async def private_responses(request: Request, call_next: Any) -> Response:
    if request.url.path.startswith("/v1/") and request.headers.get("X-DM-Contract", "1") != "1":
        return Response(
            '{"detail":{"code":"upgrade_required"}}',
            status_code=426,
            media_type="application/json",
            headers={"Cache-Control": "private, no-store"},
        )
    response: Response = await call_next(request)
    response.headers["Cache-Control"] = "private, no-store"
    return response


@app.get("/healthz")
def health() -> dict[str, str]:
    return {"status": "ok", "milestone": "phase-0"}


@app.get("/readyz", include_in_schema=False)
def ready() -> dict[str, str]:
    settings().validate_hosted()
    try:
        database_readiness()
    except SQLAlchemyError:
        raise HTTPException(503, detail={"code": "database_unavailable"}) from None
    return {"status": "ready"}


@app.get("/v1/me", response_model=MeResponse)
def get_me(owner: Owner) -> dict[str, Any]:
    return me(owner)


@app.post("/v1/account/initialize", response_model=AccountResponse)
def initialize(
    request: AccountInitializeRequest,
    owner: Owner,
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer)],
) -> dict[str, Any]:
    current_provider_identity(owner, credentials.credentials)
    return initialize_account(owner)


@app.post("/v1/sync/push", response_model=PushResponse)
def push(request: PushRequest, owner: Owner) -> dict[str, Any]:
    results = [accept(owner, op) for op in request.operations]
    context = me(owner)
    return {
        key: context[key] for key in ["schema_version", "owner_id", "generation", "erasure_epoch"]
    } | {"results": results}


@app.get("/v1/sync/pull", response_model=PullResponse)
def get_pull(
    owner: Owner, cursor: str | None = None, limit: Annotated[int, Query(ge=1, le=100)] = 100
) -> dict[str, Any]:
    return pull(owner, cursor, limit)


@app.post("/v1/sync/bootstrap", response_model=BootstrapManifest)
def post_bootstrap(request: BootstrapRequest, owner: Owner) -> dict[str, Any]:
    return bootstrap(owner, request.installation_id)


@app.get(
    "/v1/sync/bootstrap/pages/{page}",
    response_model=SnapshotPage,
    response_model_exclude_unset=True,
)
def get_page(owner: Owner, token: str, page: Annotated[int, Path(ge=0)]) -> dict[str, Any]:
    return snapshot_page(owner, token, page)


@app.get("/v1/sync/bootstrap/validate", response_model=MeResponse)
def validate(owner: Owner, token: str) -> dict[str, Any]:
    return validate_snapshot(owner, token)
