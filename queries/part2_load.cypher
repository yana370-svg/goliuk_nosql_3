
// 1. СТВОРЕННЯ ІНДЕКСІВ (прискорює MATCH/MERGE)
// ==========================================
CREATE INDEX user_id_idx IF NOT EXISTS FOR (u:User) ON (u.userId);
CREATE INDEX movie_id_idx IF NOT EXISTS FOR (m:Movie) ON (m.movieId);
CREATE INDEX genre_name_idx IF NOT EXISTS FOR (g:Genre) ON (g.name);


// 2. ЗАВАНТАЖЕННЯ ВУЗЛІВ: КОРИСТУВАЧІ
// ==========================================
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);


// 3. ЗАВАНТАЖЕННЯ ВУЗЛІВ: ФІЛЬМИ ТА ЖАНРИ
// ==========================================
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title
WITH m, row.genres AS genresString
// Розбиваємо рядок жанрів "Action|Comedy" на список і створюємо вузли Genre
UNWIND split(genresString, '|') AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);


// 4. ЗАВАНТАЖЕННЯ РЕБЕР: ОЦІНКИ (через APOC)
// ==========================================
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  "MATCH (u:User {userId: toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   SET r.rating = toFloat(row.rating), r.timestamp = toInteger(row.timestamp)",
  {batchSize: 10000, parallel: false}
) YIELD batches, total, timeTaken
RETURN batches, total, timeTaken;

// 5. ПЕРЕВІРКА РЕЗУЛЬТАТІВ
// ==========================================
MATCH (u:User) RETURN count(u) AS users;
MATCH (m:Movie) RETURN count(m) AS movies;
MATCH ()-[r:RATED]->() RETURN count(r) AS ratings;