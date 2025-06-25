<?php
$logfile = "/tmp/unraid-secfix.log";

// Simple test output
echo "✅ Unraid SecFix checkSecurity.php is working.\n";

// Write to log file
file_put_contents($logfile, "[" . date('Y-m-d H:i:s') . "] Security check ran.\n", FILE_APPEND);
?>
