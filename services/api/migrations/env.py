from alembic import context
from sqlalchemy import create_engine

from daily_motion.config import settings

# Only this migration process receives administrator credentials.
with create_engine(settings().database_url).connect() as connection:
    context.configure(connection=connection)
    with context.begin_transaction():
        context.run_migrations()
