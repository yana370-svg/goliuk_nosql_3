
// 5.1. PageRank на графі фільмів
// ==========================================
// Крок 1: матеріалізуємо ребра фільм-фільм через спільних користувачів
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE COUNT { (m1)<-[:RATED]-() } > 20
  AND COUNT { (m2)<-[:RATED]-() } > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Крок 2: створюємо проєкцію
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: запуск PageRank та вивід топ-10 фільмів
CALL gds.pageRank.stream('movieGraph', {
  relationshipWeightProperty: 'weight'
})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS movie, score
ORDER BY score DESC
LIMIT 10
RETURN movie.title AS title, round(score * 10000) / 10000.0 AS pageRankScore;

// Крок 4: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]-() DELETE co;



// 5.2. Виявлення спільнот (Louvain)
// ==========================================
// Крок 1: матеріалізуємо ребра користувач-користувач (тільки за оцінками 5.0 для економії пам'яті)
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating = 5 AND r2.rating = 5 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WHERE weight >= 5
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 20000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: створюємо проєкцію
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: записуємо communityId у вузли через .write і виводимо топ-10 найбільших кластерів
CALL gds.louvain.write('userSimilarity', {
  writeProperty: 'communityId',
  relationshipWeightProperty: 'weight'
})
YIELD communityCount, modularity;

MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS communityId, count(*) AS clusterSize
ORDER BY clusterSize DESC
LIMIT 10
RETURN communityId, clusterSize;

// Крок 4: топ-3 популярні жанри (за оцінками >= 4) для кожного з 5 найбільших кластерів
MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS communityId, count(u) AS clusterSize
ORDER BY clusterSize DESC
LIMIT 5
MATCH (u:User {communityId: communityId})-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH communityId, clusterSize, g.name AS genre, count(*) AS genreRatings
ORDER BY communityId, genreRatings DESC
WITH communityId, clusterSize, collect({genre: genre, count: genreRatings})[0..3] AS top3Genres
RETURN communityId, clusterSize, top3Genres
ORDER BY clusterSize DESC;

// Крок 5: очищення проєкції та тимчасових властивостей (ребра SIMILAR залишаємо для пункту 5.3!)
CALL gds.graph.drop('userSimilarity');
MATCH (u:User) REMOVE u.communityId;



// 5.3. Найкоротший шлях (Dijkstra)
// ==========================================
//Варіант 1
// Крок 1: створюємо проєкцію на основі вже існуючих ребер SIMILAR
CALL gds.graph.project(
 'userGraph',
 'User',
 { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 2: пошук найкоротшого шляху між кількома парами користувачів (за кількістю хопів)
UNWIND [[1, 100], [1, 500], [50, 1200], [10, 3000]] AS pair
MATCH (source:User {userId: pair[0]}), (target:User {userId: pair[1]})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
 sourceNode: source,
 targetNode: target
})
YIELD nodeIds, totalCost
RETURN pair[0] AS fromUser,
 pair[1] AS toUser,
 toInteger(totalCost) AS hops,
 [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS pathUserIds;

// Крок 3: фінальне видалення проєкції та тимчасових ребер
CALL gds.graph.drop('userGraph');
MATCH ()-[sim:SIMILAR]-() DELETE sim;


//Варіант 2 з підстановкою у UNWIND реальних userId користувачів, які мають зв'язки SIMILAR
// Крок 1: матеріалізуємо ребра схожості
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating = 5 AND r2.rating = 5 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WHERE weight >= 5
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 20000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: створюємо проєкцію графа в пам'яті GDS
CALL gds.graph.project(
  'userGraph',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: автоматично беремо 6 зв'язаних користувачів із графа та шукаємо шляхи між різними парами
MATCH (u:User)
WHERE COUNT { (u)-[:SIMILAR]-() } > 0
WITH collect(u)[0..6] AS users
UNWIND [
  [users[0], users[1]], 
  [users[0], users[3]], 
  [users[1], users[4]], 
  [users[2], users[5]], 
  [users[3], users[5]]
] AS pair
WITH pair[0] AS source, pair[1] AS target
CALL gds.shortestPath.dijkstra.stream('userGraph', {
  sourceNode: source,
  targetNode: target
})
YIELD nodeIds, totalCost
RETURN source.userId AS fromUser,
       target.userId AS toUser,
       toInteger(totalCost) AS hops,
       [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS pathUserIds;

// Крок 4: фінальне видалення проєкції та тимчасових ребер
CALL gds.graph.drop('userGraph');
MATCH ()-[sim:SIMILAR]-() DELETE sim;
