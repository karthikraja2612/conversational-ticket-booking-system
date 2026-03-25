import json
from pathlib import Path
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from .. import models

_movies_cache: List[Dict[str, Any]] | None = None
_showtimes_cache: List[Dict[str, Any]] | None = None


def _load_json(path: Path) -> List[Dict[str, Any]]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Failed to load dataset {path.name}: {exc}")
        return []


def _load_movies() -> List[Dict[str, Any]]:
    global _movies_cache
    if _movies_cache is not None:
        return _movies_cache

    data_path = Path(__file__).resolve().parents[2] / "data" / "movies.json"
    _movies_cache = _load_json(data_path)
    return _movies_cache


def _load_showtimes() -> List[Dict[str, Any]]:
    global _showtimes_cache
    if _showtimes_cache is not None:
        return _showtimes_cache

    data_path = Path(__file__).resolve().parents[2] / "data" / "showtimes.json"
    _showtimes_cache = _load_json(data_path)
    return _showtimes_cache


def ensure_movie_seed(db: Session) -> None:
    if db.query(models.Movie).count() == 0:
        movies = [
            models.Movie(
                id=movie.get("id"),
                title=movie.get("title"),
                genre=movie.get("genre"),
                duration_min=movie.get("duration_min"),
                language=movie.get("language"),
            )
            for movie in _load_movies()
        ]
        if movies:
            db.bulk_save_objects(movies)

    if db.query(models.MovieShowtime).count() == 0:
        showtimes = [
            models.MovieShowtime(
                movie_id=item.get("movie_id"),
                theatre_name=item.get("theatre_name"),
                screen_number=item.get("screen_number"),
                show_times=item.get("show_times") or [],
            )
            for item in _load_showtimes()
        ]
        if showtimes:
            db.bulk_save_objects(showtimes)

    db.commit()


def get_movies(db: Session | None = None) -> List[Dict[str, Any]]:
    if db is None:
        return list(_load_movies())

    return [
        {
            "id": movie.id,
            "title": movie.title,
            "genre": movie.genre,
            "duration_min": movie.duration_min,
            "language": movie.language,
        }
        for movie in db.query(models.Movie).order_by(models.Movie.id).all()
    ]


def get_movies_by_theatre(theatre_name: str, db: Session | None = None) -> List[Dict[str, Any]]:
    if not theatre_name:
        return []

    if db is not None:
        theatre_key = theatre_name.strip().lower()
        movie_ids = {
            item.movie_id
            for item in db.query(models.MovieShowtime).all()
            if item.theatre_name.strip().lower() == theatre_key
        }
        return [
            {
                "id": movie.id,
                "title": movie.title,
                "genre": movie.genre,
                "duration_min": movie.duration_min,
                "language": movie.language,
            }
            for movie in db.query(models.Movie).filter(models.Movie.id.in_(movie_ids)).all()
        ]

    theatre_key = theatre_name.strip().lower()
    showtimes = _load_showtimes()
    movie_ids = {
        item.get("movie_id")
        for item in showtimes
        if isinstance(item.get("theatre_name"), str)
        and item.get("theatre_name").strip().lower() == theatre_key
    }

    return [movie for movie in _load_movies() if movie.get("id") in movie_ids]


def get_showtimes(movie_id: int, theatre_name: str, db: Session | None = None) -> Optional[List[str]]:
    if movie_id is None or not theatre_name:
        return None

    if db is not None:
        theatre_key = theatre_name.strip().lower()
        showtime = db.query(models.MovieShowtime).filter(
            models.MovieShowtime.movie_id == movie_id,
            models.MovieShowtime.theatre_name.ilike(theatre_key),
        ).first()
        if showtime:
            return list(showtime.show_times or [])
        return None

    theatre_key = theatre_name.strip().lower()
    for item in _load_showtimes():
        if item.get("movie_id") != movie_id:
            continue
        if not isinstance(item.get("theatre_name"), str):
            continue
        if item.get("theatre_name").strip().lower() != theatre_key:
            continue
        show_times = item.get("show_times")
        return list(show_times) if isinstance(show_times, list) else []

    return None


def get_theatres_for_movie(movie_id: int, db: Session | None = None) -> List[str]:
    if movie_id is None:
        return []

    if db is not None:
        theatres = [
            item.theatre_name
            for item in db.query(models.MovieShowtime)
            .filter(models.MovieShowtime.movie_id == movie_id)
            .all()
            if isinstance(item.theatre_name, str)
        ]
        return theatres

    theatres: List[str] = []
    seen = set()
    for item in _load_showtimes():
        if item.get("movie_id") != movie_id:
            continue
        name = item.get("theatre_name")
        if not isinstance(name, str):
            continue
        key = name.strip().lower()
        if not key or key in seen:
            continue
        theatres.append(name)
        seen.add(key)
    return theatres


def get_theatre_names(db: Session | None = None) -> List[str]:
    if db is not None:
        return [
            item[0]
            for item in db.query(models.MovieShowtime.theatre_name)
            .distinct()
            .all()
            if isinstance(item[0], str)
        ]

    theatres: List[str] = []
    seen = set()
    for item in _load_showtimes():
        name = item.get("theatre_name")
        if not isinstance(name, str):
            continue
        key = name.strip().lower()
        if not key or key in seen:
            continue
        theatres.append(name)
        seen.add(key)
    return theatres
