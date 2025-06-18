<?php
header('Content-Type: application/json');

// 1) Sanitize via regex: solo SELECT … FROM … [;]
/*
function is_safe_query(string $sql): bool {
    // non più di un ';'
    if (substr_count($sql, ';') > 1) return false;
    // SOLO pattern SELECT … FROM … [;]
    return (bool) preg_match(
        '/^\s*SELECT\s+[A-Za-z0-9_\*\.,\s]+\s+FROM\s+[A-Za-z0-9_\.]+;?\s*$/i',
        $sql
    );
}
*/

function checkAndSanitize(string $sql): bool {
    // Normalize and trim the SQL
    $sql = trim(preg_replace('/\\s+/', ' ', $sql));

    // Block multiple statements
    if (substr_count($sql, ';') > 1) return false;

    // Basic SELECT-FROM with optional WHERE
    $pattern = '/^SELECT\s+([a-zA-Z0-9_\.\*]+(?:\s*,\s*[a-zA-Z0-9_\.\*]+)*)\s+FROM\s+[a-zA-Z0-9_\.]+(\s+WHERE\s+[a-zA-Z0-9_\.\s=><\'"]+)?\s*;?$/i';

    // Reject dangerous SQL keywords
    $blacklist = ['UNION', 'JOIN', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'TRUNCATE', 'GRANT', 'REVOKE', 'EXEC', 'CALL', 'SET', '--', '/*', '*/'];

    foreach ($blacklist as $keyword) {
        if (stripos($sql, $keyword) !== false) return false;
    }

    return (bool) preg_match($pattern, $sql);
}


// 2) Prendi parametri
// Read JSON body
$input = json_decode(file_get_contents('php://input'), true);
$db       = $input['db']       ?? '';
$user     = $input['user']     ?? '';
$password = $input['password'] ?? '';
$query    = $input['query']    ?? '';
$client_ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';

$log_entry = [
    'timestamp' => date('Y-m-d H:i:s'),
    'client_ip' => $client_ip,
    'db' => $db,
    'user' => $user,
    'query' => $query,
    'error' => null,
    'rows_returned' => 0
];

// 3) Verifica parametri
if (!$db || !$user || !$password || !$query) {
    http_response_code(400);
    echo json_encode(['error'=>'Missing parameters']);
    exit;
}

// 4) Sanitizza
//if (!is_safe_query($query)) {
if (!checkAndSanitize($query)) {
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
    
    // logging
    $log_entry['rows_returned'] = count($rows);
    
    echo json_encode($rows);

} catch (PDOException $e) {
    http_response_code(500);
    $log_entry['error'] = $e->getMessage();
    echo json_encode(['error' => $e->getMessage()]);
} finally {
    $log_line = json_encode($log_entry) . PHP_EOL;
    file_put_contents('/var/log/queries/query_logs.txt', $log_line, FILE_APPEND);
}