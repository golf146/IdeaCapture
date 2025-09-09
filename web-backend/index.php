<?php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// 如果 URL 是 /index.php/xxx，则去掉 /index.php 部分
if (strpos($path, '/index.php/') === 0) {
    $path = substr($path, strlen('/index.php'));
}

// 如果是直接访问 /index.php（没有后缀），就设成根路径
if ($path === '/index.php') {
    $path = '/';
}

// 数据库配置
$dsn = "mysql:host=127.0.0.1;dbname=ideaapi_jackiezy;charset=utf8mb4";
$dbUser = "你的数据库用户";
$dbPass = "你的数据库密码";
$pdo = new PDO($dsn, $dbUser, $dbPass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

// JWT 设置
$jwtSecret = 'vW8P6h32cYzqjEr4bK5n1mFJ9pTgA7LuXeQ0oHZI3lNUsyRkCM2dVfG4SWta8BJD';
function makeJWT($uid, $secret) {
    $header = base64_encode(json_encode(['alg'=>'HS256','typ'=>'JWT']));
    $payload = base64_encode(json_encode(['uid'=>$uid,'exp'=>time()+86400*30]));
    $sig = base64_encode(hash_hmac('sha256',"$header.$payload",$secret,true));
    return "$header.$payload.$sig";
}
function checkJWT($token, $secret) {
    $parts = explode('.', $token);
    if(count($parts)!=3) return null;
    [$h,$p,$s] = $parts;
    $sig = base64_encode(hash_hmac('sha256',"$h.$p",$secret,true));
    if(!hash_equals($sig,$s)) return null;
    $pl = json_decode(base64_decode($p),true);
    if(!$pl || time() > $pl['exp']) return null;
    return $pl['uid'] ?? null;
}

// 路由处理
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];
header('Content-Type: application/json');

// ===== 注册 =====
if (preg_match('#/auth/register$#', $path) && $method === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    if (empty($data['email']) || empty($data['password'])) {
        http_response_code(400); echo json_encode(['error'=>'email and password required']); exit;
    }
    $hash = password_hash($data['password'], PASSWORD_BCRYPT);
    $stmt = $pdo->prepare("INSERT INTO users(email,password_hash) VALUES(?,?)");
    $stmt->execute([$data['email'],$hash]);
    echo json_encode(['ok'=>true]); exit;
}

// ===== 登录 =====
if (preg_match('#/auth/login$#', $path) && $method === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    if (empty($data['email']) || empty($data['password'])) {
        http_response_code(400); echo json_encode(['error'=>'email and password required']); exit;
    }
    $stmt = $pdo->prepare("SELECT id,password_hash FROM users WHERE email=?");
    $stmt->execute([$data['email']]);
    $u = $stmt->fetch(PDO::FETCH_ASSOC);
    if(!$u || !password_verify($data['password'],$u['password_hash'])){
        http_response_code(401); echo json_encode(['error'=>'invalid']); exit;
    }
    echo json_encode(['token'=>makeJWT($u['id'],$jwtSecret)]); exit;
}

// ===== 上传快照 =====
if (preg_match('#/sync/upload$#', $path) && $method === 'POST') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if(!preg_match('/Bearer\s+(.+)/',$auth,$m)){ http_response_code(401); exit; }
    $uid = checkJWT($m[1],$jwtSecret); if(!$uid){ http_response_code(401); exit; }
    $data = file_get_contents('php://input');
    $stmt = $pdo->prepare("INSERT INTO snapshots(user_id,json) VALUES(?,?)
        ON DUPLICATE KEY UPDATE json=VALUES(json), updated_at=NOW()");
    $stmt->execute([$uid,$data]);
    echo json_encode(['ok'=>true]); exit;
}

// ===== 下载快照 =====
if (preg_match('#/sync/download$#', $path) && $method === 'GET') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if(!preg_match('/Bearer\s+(.+)/',$auth,$m)){ http_response_code(401); exit; }
    $uid = checkJWT($m[1],$jwtSecret); if(!$uid){ http_response_code(401); exit; }
    $stmt = $pdo->prepare("SELECT json FROM snapshots WHERE user_id=? ORDER BY updated_at DESC LIMIT 1");
    $stmt->execute([$uid]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    echo $row ? $row['json'] : '{}'; exit;
}

// ===== /user/info =====
if (preg_match('#/user/info$#', $path) && $method === 'GET') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+(.+)/', $auth, $m)) { http_response_code(401); exit; }
    $uid = checkJWT($m[1], $jwtSecret);
    if (!$uid) { http_response_code(401); exit; }

    $stmt = $pdo->prepare("SELECT id, email, DEV_MODE FROM users WHERE id=?");
    $stmt->execute([$uid]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($row) {
        $row['DEV_MODE'] = $row['DEV_MODE'] == 1 ? true : false;
        echo json_encode($row);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'not found']);
    }
    exit;
}

// ===== 获取项目和观点 =====
if (preg_match('#/projects$#', $path) && $method === 'GET') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+(.+)/', $auth, $m)) { http_response_code(401); exit; }
    $uid = checkJWT($m[1], $jwtSecret); if (!$uid) { http_response_code(401); exit; }

    $stmt = $pdo->prepare("SELECT id, user_id, name, summary, tags, goals, audience, created_at, updated_at, created_device_udid, updated_device_udid, current_opinion_id
                            FROM projects
                            WHERE user_id=?");
    $stmt->execute([$uid]);
    $projects = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $stmt = $pdo->prepare("SELECT id, project_id, version, opinion, prev_opinion_id, created_at, device_udid
                            FROM project_opinions
                            WHERE project_id IN (SELECT id FROM projects WHERE user_id=?)");
    $stmt->execute([$uid]);
    $opinions = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['projects' => $projects, 'opinions' => $opinions]);
    exit;
}

// ===== 上传项目和观点（已改为支持多条 opinion） =====
if (preg_match('#/projects$#', $path) && $method === 'POST') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+(.+)/', $auth, $m)) { http_response_code(401); exit; }
    $uid = checkJWT($m[1],$jwtSecret); if (!$uid) { http_response_code(401); exit; }

    $data = json_decode(file_get_contents('php://input'), true);
    if (!$data) { http_response_code(400); echo json_encode(['error' => 'invalid json']); exit; }

    function genUuidV4() {
        return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }

    if (!empty($data['projects'])) {
        $stmt = $pdo->prepare("INSERT INTO projects
            (id, user_id, name, summary, tags, goals, audience, created_at, updated_at, created_device_udid, updated_device_udid, current_opinion_id)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
            ON DUPLICATE KEY UPDATE
                name=VALUES(name),
                summary=VALUES(summary),
                tags=VALUES(tags),
                goals=VALUES(goals),
                audience=VALUES(audience),
                created_at=VALUES(created_at),
                updated_at=VALUES(updated_at),
                created_device_udid=VALUES(created_device_udid),
                updated_device_udid=VALUES(updated_device_udid),
                current_opinion_id=VALUES(current_opinion_id)");
        foreach ($data['projects'] as $p) {
            $stmt->execute([
                $p['id'] ?? genUuidV4(),
                $uid,
                $p['name'] ?? null,
                $p['summary'] ?? null,
                isset($p['tags']) ? json_encode($p['tags'], JSON_UNESCAPED_UNICODE) : null,
                $p['goals'] ?? null,
                $p['audience'] ?? null,
                $p['created_at'] ?? null,
                $p['updated_at'] ?? null,
                $p['created_device_udid'] ?? null,
                $p['updated_device_udid'] ?? null,
                $p['current_opinion_id'] ?? null
            ]);
        }
    }

    if (!empty($data['opinions'])) {
        $stmt = $pdo->prepare("INSERT IGNORE INTO project_opinions
            (id, project_id, version, opinion, prev_opinion_id, created_at, device_udid)
            VALUES (?,?,?,?,?,?,?)");

        foreach ($data['opinions'] as $o) {
            $version = isset($o['version']) && $o['version'] ? $o['version'] : (int)round(microtime(true) * 1000);
            $stmt->execute([
                $o['id'] ?? genUuidV4(),
                $o['project_id'],
                $version,
                $o['opinion'],
                $o['prev_opinion_id'] ?? null,
                $o['created_at'] ?? null,
                $o['device_udid'] ?? null
            ]);
            usleep(1000);
        }
    }

    echo json_encode(['ok' => true]);
    exit;
}

// ===== 批量上传 ideas =====
if (preg_match('#/ideas/batch$#', $path) && $method === 'POST') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/Bearer\s+(.+)/', $auth, $m)) { http_response_code(401); exit; }
    $uid = checkJWT($m[1],$jwtSecret);
    if (!$uid) { http_response_code(401); exit; }

    $data = json_decode(file_get_contents('php://input'), true);
    if (!$data) { http_response_code(400); echo json_encode(['error' => 'invalid json']); exit; }

    if (!empty($data['project']) && !empty($data['ideas'])) {
        $stmt = $pdo->prepare("SELECT id FROM projects WHERE user_id=? AND name=? LIMIT 1");
        $stmt->execute([$uid, $data['project']]);
        $projectRow = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$projectRow) {
            http_response_code(400);
            echo json_encode(['error' => 'project not found']);
            exit;
        }
        $projectId = $projectRow['id'];

        $stmt = $pdo->prepare("INSERT INTO project_opinions
            (project_id, version, opinion, prev_opinion_id, created_at, device_udid)
            VALUES (?,?,?,?,?,?)
            ON DUPLICATE KEY UPDATE
                opinion=VALUES(opinion),
                version=VALUES(version),
                prev_opinion_id=VALUES(prev_opinion_id),
                created_at=VALUES(created_at),
                device_udid=VALUES(device_udid)");

        foreach ($data['ideas'] as $idea) {
            $stmt->execute([
                $projectId,
                time(),
                $idea['content'],
                null,
                $idea['createdAt'] ?? date('Y-m-d H:i:s'),
                $idea['device_udid'] ?? null
            ]);
        }
    }

    echo json_encode(['ok' => true]);
    exit;
}

// ===== 默认 404 =====
http_response_code(404);
echo json_encode(['error'=>'not found']);
