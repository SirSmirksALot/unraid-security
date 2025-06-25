<?php
$docroot = $docroot ?? $_SERVER['DOCUMENT_ROOT'] ?: '/usr/local/emhttp';
require_once "$docroot/webGui/include/Helpers.php";

if ($_POST['run_check']) {
    exec("/usr/local/emhttp/plugins/unraid-security/unraid-security");
    $message = "✅ Security check executed. Check syslog.";
}
?>

<!DOCTYPE html>
<html>
<head>
  <title>Unraid Security Plugin</title>
</head>
<body>
  <h1>Unraid Security Plugin</h1>
  <form method="post">
    <fieldset>
      <legend>Run Security Check</legend>
      <input type="submit" name="run_check" value="Run Check">
    </fieldset>
  </form>
  <?php if (!empty($message)) echo "<p>$message</p>"; ?>
</body>
</html>
