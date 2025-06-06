<?php
header('Content-Type: application/json');

// 1) Sanitize via regex: solo SELECT … FROM … [;]
function is_safe_query(string $sql): bool {
    // non più di un ';'
    if (substr_count($sql, ';') > 1) return false;
    // SOLO pattern SELECT … FROM … [;]
    return (bool) preg_match(
        '/^\s*SELECT\s+[A-Za-z0-9_\*\.,\s]+\s+FROM\s+[A-Za-z0-9_\.]+;?\s*$/i',
        $sql
    );
}

// 2) Prendi parametri
// Read JSON body
$input = json_decode(file_get_contents('php://input'), true);
$db       = $input['db']       ?? '';
$user     = $input['user']     ?? '';
$password = $input['password'] ?? '';
$query    = $input['query']    ?? '';

// 3) Verifica parametri
if (!$db || !$user || !$password || !$query) {
    http_response_code(400);
    echo json_encode(['error'=>'Missing parameters']);
    exit;
}

// 4) Sanitizza
if (!is_safe_query($query)) {
    http_response_code(400);
    echo json_encode(['error'=>'Query non consentita']);
    exit;
}

try {
    // 5) Connessione PDO
    $dsn = "pgsql:host=127.0.0.1;port=5432;dbname={$db}";
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);

    // 6) Esecuzione + output JSON
    $stmt = $pdo->query($query);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode($rows);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error'=>$e->getMessage()]);
}