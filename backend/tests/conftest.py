"""
conftest.py — pytest fixtures for the ticketing system backend tests.

Uses an in-memory (file-based) SQLite database so that no running MySQL
instance is needed.  SQLAlchemy transparently maps Enum columns to VARCHAR
on SQLite, so all model definitions work unchanged.
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import get_db
from app.models import Base

_TEST_DB_URL = "sqlite:///./test_ticketing.db"

_engine = create_engine(
    _TEST_DB_URL,
    connect_args={"check_same_thread": False},
)
_TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=_engine)


def _override_get_db():
    db = _TestingSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(scope="session", autouse=True)
def _create_tables():
    """Create all tables once before the session, drop them afterwards."""
    Base.metadata.create_all(bind=_engine)
    yield
    Base.metadata.drop_all(bind=_engine)


@pytest.fixture(scope="session")
def client(_create_tables):
    app.dependency_overrides[get_db] = _override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture()
def db_session():
    db = _TestingSession()
    try:
        yield db
    finally:
        db.close()
