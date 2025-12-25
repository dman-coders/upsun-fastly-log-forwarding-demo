<?php
/**
 * Fastly Log Receiver
 * Receives HTTPS log posts from Fastly and appends to a log file.
 *
 * Fastly Configuration:
 * - Logging > HTTPS
 * - URL: https://your-app.upsun.sh/log-receiver.php
 * - Method: POST
 * - Content Type: application/json
 */

// Configuration
define('LOG_FILE', getenv('PLATFORM_APP_DIR') . '/logs/fastly.log');
define('AUTH_TOKEN', getenv('FASTLY_LOG_TOKEN')); // Set via Upsun environment variable

// Set response headers
// Fastly API doesn't pay attention to anything but status code.
header('Content-Type: application/json');

// TODO: Authentication - verify token or IP restriction
// Example token check:
// $headers = getallheaders();
// if (!isset($headers['X-Auth-Token']) || $headers['X-Auth-Token'] !== AUTH_TOKEN) {
//     http_response_code(403);
//     exit('Unauthorized');
// }

// Read incoming POST data
$rawData = file_get_contents('php://input');

if (empty($rawData)) {
  http_response_code(400);
  echo json_encode(['status' => 'error', 'message' => 'No data received']);
  exit;
}
// Append to log file (one line per POST)
// Fastly may send multiple log lines in one POST as newline-delimited JSON
$bytes = @file_put_contents(LOG_FILE, $rawData . PHP_EOL, FILE_APPEND | LOCK_EX);
if ($bytes === false) {
    http_response_code(500);
    $err = error_get_last();
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to write to log file',
        'error' => $err ? $err['message'] : null
    ]);
    exit;
}

// Respond success
http_response_code(200);
echo json_encode(['status' => 'success', 'bytes' => $bytes]);
