// Запит 1: Фільми жанру "Thriller" із середнім рейтингом > 4.0
MATCH (g:Genre {name: 'Thriller'})<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH m, avg(r.rating) AS avgRating, count(r) AS reviewCount
WHERE avgRating > 4.0 AND reviewCount > 50 // фільтр на мінімальну кількість відгуків для достовірності
RETURN m.title, avgRating, reviewCount
ORDER BY avgRating DESC
LIMIT 10;

// Запит 2: Користувачі, які поставили оцінку 5 більш ніж 50 фільмам
MATCH (u:User)-[r:RATED]->()
WHERE r.rating = 5.0
WITH u, count(r) AS fiveStarCount
WHERE fiveStarCount > 50
RETURN u.userId, u.gender, u.age, fiveStarCount
ORDER BY fiveStarCount DESC
LIMIT 10;

// Запит 3: Фільми, які обидва користувачі (1 і 2) оцінили високо (>= 4)
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.title, r1.rating AS rating_u1, r2.rating AS rating_u2
ORDER BY (r1.rating + r2.rating) DESC;

// Запит 4: Жанри зі стабільно високими оцінками (середній рейтинг і кількість)
MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH g.name AS genre, avg(r.rating) AS avgRating, count(r) AS totalRatings
WHERE totalRatings > 5000 // відсіюємо нішеві жанри з малою статистикою
RETURN genre, round(avgRating * 100) / 100.0 AS avgRating, totalRatings
ORDER BY avgRating DESC
LIMIT 10;

// Запит 5: Рекомендація "користувачі зі схожими смаками також дивилися" (для userId = 1)
MATCH (me:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(similar:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND me <> similar
WITH me, similar, count(m) AS commonMovies
ORDER BY commonMovies DESC
LIMIT 50 // беремо 50 найбільш схожих користувачів
MATCH (similar)-[r3:RATED]->(rec:Movie)
WHERE r3.rating >= 4 AND NOT (me)-[:RATED]->(rec) // фільм, який я ще не дивився, але його високо оцінили
WITH rec, avg(r3.rating) AS avgRecRating, count(r3) AS recCount
WHERE recCount >= 5 // мінімум 5 рекомендацій від схожих користувачів
RETURN rec.title, round(avgRecRating * 100) / 100.0 AS predictedRating, recCount
ORDER BY predictedRating DESC, recCount DESC
LIMIT 10;

// Запит 6: Найкоротший ланцюжок зв’язку між користувачами 1 та 100 через спільні фільми
MATCH path = shortestPath((u1:User {userId: 1})-[:RATED*..6]-(u2:User {userId: 100}))
RETURN path, length(path) AS pathLength;
