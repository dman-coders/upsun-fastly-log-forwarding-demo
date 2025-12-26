<?php

shell_exec("goaccess $PLATFORM_DIR/logs/fastly.log --log-format=COMBINED -o $PLATFORM_DIR/web/reports/index.html");

# Once this process is complete, return an image for success
# thus, calling this page via HTML img src will execute async, and render OK when done.
header('Content-Type: image/svg+xml');
?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <circle cx="50" cy="50" r="45" fill="#22c55e" stroke="#16a34a" stroke-width="3"/>
  <path d="M 30 50 L 45 65 L 70 35"
        stroke="white"
        stroke-width="8"
        stroke-linecap="round"
        stroke-linejoin="round"
        fill="none"/>
</svg>