#!/usr/bin/env bash

# Copyright (c) 2025 GM5DNA
# Author: GM5DNA
# License: MIT
# https://github.com/GM5DNA/proxmox-hamclock-lxc

# Standalone script to add auto-start functionality to existing HamClock installation

# Simple message functions
msg_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
msg_ok() { echo -e "\033[0;32m[OK]\033[0m $1"; }
msg_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; exit 1; }

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  msg_error "This script must be run as root"
fi

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
  msg_error "Nginx is not installed. Please install nginx first."
fi

msg_info "Installing HamClock Auto-Start Feature"

# Install fcgiwrap for CGI support
msg_info "Installing fcgiwrap for CGI support"
apt-get update >/dev/null 2>&1
apt-get install -y fcgiwrap >/dev/null 2>&1
msg_ok "Installed fcgiwrap"

# Create CGI directory
mkdir -p /usr/lib/cgi-bin
chmod 755 /usr/lib/cgi-bin

# Install the CGI script
msg_info "Installing startup API script"
cat > /usr/lib/cgi-bin/start-hamclock.sh << 'CGI_EOF'
#!/usr/bin/env bash

# API endpoint script to start HamClock service
# Called by nginx when user accesses HamClock while service is stopped

# Print HTTP status first
echo "Status: 200 OK"
echo "Content-Type: application/json"
echo ""

# Check if service is already running
if systemctl is-active --quiet hamclock.service; then
    echo '{"status":"running","message":"HamClock is already running"}'
    exit 0
fi

# Start the service
if systemctl start hamclock.service 2>&1; then
    echo '{"status":"starting","message":"HamClock service started successfully"}'
    logger -t hamclock-api "HamClock started via web interface"
    exit 0
else
    echo '{"status":"error","message":"Failed to start HamClock service"}'
    exit 1
fi
CGI_EOF

chmod +x /usr/lib/cgi-bin/start-hamclock.sh
msg_ok "Installed startup API script"

# Create web directory for custom pages
mkdir -p /var/www/hamclock
chmod 755 /var/www/hamclock

# Install the custom starting page
msg_info "Installing custom starting page"
cat > /var/www/hamclock/hamclock-starting.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HamClock Starting...</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #fff;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            text-align: center;
            max-width: 600px;
        }

        .logo {
            font-size: 48px;
            margin-bottom: 20px;
        }

        h1 {
            font-size: 32px;
            margin-bottom: 10px;
            font-weight: 600;
        }

        .subtitle {
            font-size: 18px;
            opacity: 0.9;
            margin-bottom: 40px;
        }

        .spinner {
            width: 60px;
            height: 60px;
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-top: 4px solid #fff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 30px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .status {
            font-size: 16px;
            opacity: 0.8;
            margin-bottom: 20px;
            min-height: 24px;
        }

        .progress-bar {
            width: 100%;
            height: 6px;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 3px;
            overflow: hidden;
            margin-bottom: 30px;
        }

        .progress-fill {
            height: 100%;
            background: #4CAF50;
            border-radius: 3px;
            animation: progress 15s ease-out forwards;
        }

        @keyframes progress {
            0% { width: 0%; }
            10% { width: 30%; }
            50% { width: 60%; }
            90% { width: 85%; }
            100% { width: 95%; }
        }

        .info {
            font-size: 14px;
            opacity: 0.7;
            line-height: 1.6;
        }

        .manual-link {
            margin-top: 30px;
            padding-top: 30px;
            border-top: 1px solid rgba(255, 255, 255, 0.2);
        }

        .manual-link a {
            color: #4CAF50;
            text-decoration: none;
            font-weight: 500;
        }

        .manual-link a:hover {
            text-decoration: underline;
        }

        .error {
            color: #ff6b6b;
            margin-top: 20px;
            font-weight: 500;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">📡</div>
        <h1>HamClock is Starting</h1>
        <p class="subtitle">Please wait while we bring up the service...</p>

        <div class="spinner"></div>

        <div class="progress-bar">
            <div class="progress-fill"></div>
        </div>

        <div class="status" id="status">Initializing...</div>

        <div class="info">
            <p>HamClock was stopped to save CPU resources when not in use.</p>
            <p>The service takes approximately 10-15 seconds to start.</p>
        </div>

        <div class="manual-link">
            <p>If this page doesn't redirect automatically, <a href="/live.html">click here</a> to try again.</p>
        </div>
    </div>

    <script>
        let attempts = 0;
        const maxAttempts = 30;
        const pollInterval = 1000; // 1 second

        function updateStatus(message) {
            document.getElementById('status').textContent = message;
        }

        async function startHamClock() {
            try {
                updateStatus('Requesting service start...');
                const response = await fetch('/api/start-hamclock', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' }
                });

                if (response.ok) {
                    updateStatus('Service start initiated, waiting for HamClock...');
                    return true;
                } else {
                    updateStatus('Start request sent, waiting...');
                    return true;
                }
            } catch (error) {
                updateStatus('Start request sent, waiting...');
                return true; // Continue anyway, service might be starting
            }
        }

        async function checkHamClock() {
            try {
                const response = await fetch('/live.html', {
                    method: 'HEAD',
                    cache: 'no-cache'
                });

                if (response.ok) {
                    updateStatus('HamClock is ready! Redirecting...');
                    setTimeout(() => {
                        window.location.href = '/live.html';
                    }, 500);
                    return true;
                }
            } catch (error) {
                // Still starting
            }
            return false;
        }

        async function pollHamClock() {
            attempts++;

            if (attempts > maxAttempts) {
                updateStatus('Service is taking longer than expected...');
                document.querySelector('.manual-link').innerHTML +=
                    '<p class="error">Please wait a bit longer or <a href="/live.html">click here</a> to try manually.</p>';
                return;
            }

            const ready = await checkHamClock();

            if (!ready) {
                updateStatus(`Waiting for HamClock... (${attempts}/${maxAttempts})`);
                setTimeout(pollHamClock, pollInterval);
            }
        }

        // Start the process
        (async function() {
            await startHamClock();
            setTimeout(pollHamClock, 2000); // Wait 2 seconds before first check
        })();
    </script>
</body>
</html>
HTML_EOF

chmod 644 /var/www/hamclock/hamclock-starting.html
msg_ok "Installed custom starting page"

# Update nginx configuration
msg_info "Updating nginx configuration"

# Backup existing config
cp /etc/nginx/sites-available/hamclock /etc/nginx/sites-available/hamclock.backup

# Create new configuration with auto-start
cat > /etc/nginx/sites-available/hamclock << 'NGINX_EOF'
# Map to determine the proper scheme (handle reverse proxy)
map $http_x_forwarded_proto $redirect_scheme {
    default $scheme;
    https https;
    http http;
}

# Map for WebSocket upgrade handling
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

# Full access on port 80
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Custom error page for 502 (HamClock not running)
    error_page 502 =200 /hamclock-starting.html;

    # Serve the custom starting page
    location = /hamclock-starting.html {
        root /var/www/hamclock;
        internal;
    }

    # API endpoint to start HamClock
    location = /api/start-hamclock {
        # Allow starting via API
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /usr/lib/cgi-bin/start-hamclock.sh;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
    }

    # Redirect root to live.html (preserve scheme for HTTPS proxies)
    location = / {
        return 301 $redirect_scheme://$host/live.html;
    }

    # Proxy all other requests to HamClock full access (port 18081)
    location / {
        proxy_pass http://127.0.0.1:18081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        # Forward WebSocket-specific headers for reverse proxy compatibility
        proxy_set_header Sec-WebSocket-Key $http_sec_websocket_key;
        proxy_set_header Sec-WebSocket-Version $http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Extensions $http_sec_websocket_extensions;
        proxy_set_header Sec-WebSocket-Protocol $http_sec_websocket_protocol;
        proxy_set_header Origin $http_origin;
        proxy_read_timeout 86400;
        proxy_connect_timeout 2s;
    }
}

# Read-only access on port 8082
server {
    listen 8082 default_server;
    listen [::]:8082 default_server;
    server_name _;

    # Custom error page for 502 (HamClock not running)
    error_page 502 =200 /hamclock-starting.html;

    # Serve the custom starting page
    location = /hamclock-starting.html {
        root /var/www/hamclock;
        internal;
    }

    # API endpoint to start HamClock (also available on read-only port)
    location = /api/start-hamclock {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /usr/lib/cgi-bin/start-hamclock.sh;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
    }

    # Redirect root to live.html for read-only access (preserve scheme)
    location = / {
        return 301 $redirect_scheme://$host:8082/live.html;
    }

    # Proxy all other requests to HamClock read-only (port 18082)
    location / {
        proxy_pass http://127.0.0.1:18082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        # Forward WebSocket-specific headers for reverse proxy compatibility
        proxy_set_header Sec-WebSocket-Key $http_sec_websocket_key;
        proxy_set_header Sec-WebSocket-Version $http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Extensions $http_sec_websocket_extensions;
        proxy_set_header Sec-WebSocket-Protocol $http_sec_websocket_protocol;
        proxy_set_header Origin $http_origin;
        proxy_read_timeout 86400;
        proxy_connect_timeout 2s;
    }
}
NGINX_EOF

# Test nginx configuration
if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx
    msg_ok "Updated nginx configuration"
else
    msg_error "Nginx configuration test failed. Restoring backup..."
    mv /etc/nginx/sites-available/hamclock.backup /etc/nginx/sites-available/hamclock
    exit 1
fi

# Enable and start fcgiwrap
systemctl enable fcgiwrap >/dev/null 2>&1
systemctl start fcgiwrap

if systemctl is-active --quiet fcgiwrap; then
    msg_ok "fcgiwrap service started"
else
    msg_error "Failed to start fcgiwrap service"
fi

echo ""
msg_ok "Auto-start feature installed successfully!"
echo ""
echo "Features:"
echo "  - Custom 'Starting...' page instead of 502 errors"
echo "  - Automatic service start when accessing HamClock"
echo "  - Auto-redirect when service is ready (~15 seconds)"
echo ""
echo "Test by stopping HamClock and accessing the web interface:"
echo "  systemctl stop hamclock"
echo "  # Visit http://your-ip/ in browser"
echo ""
