from alembic import context
from sqlalchemy import create_engine
from sqlalchemy.engine import Connection

from daily_motion.config import settings


def migrate(connection: Connection) -> None:
    context.configure(connection=connection)
    with context.begin_transaction():
        context.run_migrations()


# A provisioning process can supply its own connection without putting admin
# credentials in API settings, environment overrides or command-line arguments.
supplied = context.config.attributes.get("connection")
if supplied is not None:
    migrate(supplied)
else:
    with create_engine(settings().database_url, hide_parameters=True).connect() as connection:
        migrate(connection)
