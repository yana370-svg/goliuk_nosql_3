import csv
from pathlib import Path

RAW_DIR = Path("raw_data/ml-1m")
IMPORT_DIR = Path("import")
IMPORT_DIR.mkdir(exist_ok=True)


def convert_movies():
    # Формат у .dat: MovieID::Title::Genres
    src = RAW_DIR / "movies.dat"
    dst = IMPORT_DIR / "movies.csv"
    with src.open("r", encoding="latin-1") as f_in, dst.open(
        "w", encoding="utf-8", newline=""
    ) as f_out:
        writer = csv.writer(f_out)
        writer.writerow(["movieId", "title", "genres"])
        for line in f_in:
            parts = line.rstrip("\r\n").split("::")
            if len(parts) == 3:
                writer.writerow(parts)


def convert_users():
    # Формат у .dat: UserID::Gender::Age::Occupation::Zip-code
    src = RAW_DIR / "users.dat"
    dst = IMPORT_DIR / "users.csv"
    with src.open("r", encoding="latin-1") as f_in, dst.open(
        "w", encoding="utf-8", newline=""
    ) as f_out:
        writer = csv.writer(f_out)
        writer.writerow(["userId", "gender", "age", "occupation", "zipCode"])
        for line in f_in:
            parts = line.rstrip("\r\n").split("::")
            if len(parts) == 5:
                writer.writerow(parts)


def convert_ratings():
    # Формат у .dat: UserID::MovieID::Rating::Timestamp
    src = RAW_DIR / "ratings.dat"
    dst = IMPORT_DIR / "ratings.csv"
    with src.open("r", encoding="latin-1") as f_in, dst.open(
        "w", encoding="utf-8", newline=""
    ) as f_out:
        writer = csv.writer(f_out)
        writer.writerow(["userId", "movieId", "rating", "timestamp"])
        for line in f_in:
            parts = line.rstrip("\r\n").split("::")
            if len(parts) == 4:
                writer.writerow(parts)


if __name__ == "__main__":
    print("Конвертація movies.dat...")
    convert_movies()
    print("Конвертація users.dat...")
    convert_users()
    print("Конвертація ratings.dat...")
    convert_ratings()
    print("Файли збережено в папку import/.")