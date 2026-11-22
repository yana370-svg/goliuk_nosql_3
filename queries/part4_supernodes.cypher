// Крок 1: Знайти вузли з аномально великою кількістю ребер (ступінь > 1000)
MATCH (n)
WITH n,
     labels(n)[0] AS label,
     coalesce(n.title, n.name, toString(n.userId)) AS identifier,
     COUNT { (n)--() } AS degree
WHERE degree > 1000
RETURN label, identifier, degree
ORDER BY degree DESC
LIMIT 15;

// Крок 2: Перевірити кількість зв'язків у вузлів жанрів (потенційні супервузли)
MATCH (g:Genre)
RETURN g.name AS genre, COUNT { (g)<-[:HAS_GENRE]-() } AS movieCount
ORDER BY movieCount DESC;