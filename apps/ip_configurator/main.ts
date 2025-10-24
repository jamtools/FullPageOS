import {Hono} from 'hono'

const app = new Hono()

interface IpConfig {
    touchscreen_ip: string
    gateway: string
    jace_ip: string
    timestamp: string
}

// Store user data in XDG_CONFIG_HOME or fallback to ~/.config
const CONFIG_DIR = `${Deno.env.get('HOME')}/apps`
const APP_CONFIG_DIR = `${CONFIG_DIR}/ip_configurator`
const CONFIG_FILE = `${APP_CONFIG_DIR}/ip_config.json`
const STAGING_DIR = '/var/lib/network-staging'
const STAGING_PENDING_DIR = `${STAGING_DIR}/pending`
const STAGING_STATUS_DIR = `${STAGING_DIR}/status`

interface CurrentConfig {
    touchscreen_ip: string
    gateway: string
    jace_ip: string
}

const parseNetworkConfig = async (): Promise<CurrentConfig> => {
    const defaultConfig: CurrentConfig = {
        touchscreen_ip: '192.168.1.100',
        gateway: '192.168.1.1',
        jace_ip: '192.168.1.140'
    }

    // Start with defaults
    const currentConfig: CurrentConfig = {...defaultConfig}

    // Try to get all values from our JSON config
    try {
        const jsonData = await Deno.readTextFile(CONFIG_FILE)
        const configs = JSON.parse(jsonData) as IpConfig[]
        if (configs.length > 0) {
            const latest = configs[0]
            if (latest.touchscreen_ip) currentConfig.touchscreen_ip = latest.touchscreen_ip
            if (latest.gateway) currentConfig.gateway = latest.gateway
            if (latest.jace_ip) currentConfig.jace_ip = latest.jace_ip
        }
    } catch {
        // JSON file doesn't exist yet, use defaults
    }

    return currentConfig
}

const generateHtmlForm = (currentValues: CurrentConfig, message?: string): string => {
    return `
    <!DOCTYPE html>
    <html>
    <head>
      <title>IP Address Configuration</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          max-width: 600px;
          margin: 50px auto;
          padding: 20px;
        }
        .form-group {
          margin-bottom: 15px;
        }
        label {
          display: block;
          margin-bottom: 5px;
          font-weight: bold;
        }
        input[type="text"] {
          width: 100%;
          padding: 8px;
          border: 1px solid #ddd;
          border-radius: 4px;
          font-size: 14px;
        }
        button {
          background-color: #4CAF50;
          color: white;
          padding: 10px 20px;
          border: none;
          border-radius: 4px;
          cursor: pointer;
          font-size: 16px;
          margin-right: 10px;
        }
        button:hover {
          background-color: #45a049;
        }
        button.secondary {
          background-color: #008CBA;
        }
        button.secondary:hover {
          background-color: #007399;
        }
        .message {
          padding: 10px;
          margin-bottom: 20px;
          border-radius: 4px;
        }
        .success {
          background-color: #d4edda;
          color: #155724;
          border: 1px solid #c3e6cb;
        }
        .error {
          background-color: #f8d7da;
          color: #721c24;
          border: 1px solid #f5c6cb;
        }
        .network-status {
          margin-top: 20px;
          padding: 15px;
          background-color: #f5f5f5;
          border-radius: 4px;
          border: 1px solid #ddd;
        }
        .network-status pre {
          margin: 10px 0 0 0;
          padding: 10px;
          background-color: #2d2d2d;
          color: #f8f8f2;
          border-radius: 4px;
          overflow-x: auto;
          max-height: 400px;
          overflow-y: auto;
          font-family: 'Courier New', monospace;
          font-size: 12px;
          line-height: 1.4;
        }
        .button-group {
          display: flex;
          gap: 10px;
          margin-top: 15px;
        }
      </style>
      <script>
        async function fetchNetworkStatus() {
          const statusDiv = document.getElementById('network-status');
          statusDiv.innerHTML = '<p>Loading network status...</p>';

          try {
            const response = await fetch('/network-status');
            const data = await response.json();

            if (data.error) {
              statusDiv.innerHTML = '<p style="color: #721c24;">Error: ' + data.error + '</p>';
            } else {
              statusDiv.innerHTML = '<h3>Network Status (ifconfig)</h3><pre>' + data.output + '</pre>';
            }
          } catch (error) {
            statusDiv.innerHTML = '<p style="color: #721c24;">Error fetching network status: ' + error.message + '</p>';
          }
        }

        async function toggleNetworkStatus() {
          const statusDiv = document.getElementById('network-status');
          const button = document.getElementById('network-status-btn');
          const refreshButton = document.getElementById('refresh-status-btn');

          // If already visible, hide it
          if (statusDiv.style.display === 'block') {
            statusDiv.style.display = 'none';
            button.textContent = 'Show Network Status';
            refreshButton.style.display = 'none';
            return;
          }

          // Show and load
          statusDiv.style.display = 'block';
          button.textContent = 'Hide Network Status';
          refreshButton.style.display = 'inline-block';
          await fetchNetworkStatus();
        }

        async function refreshNetworkStatus() {
          await fetchNetworkStatus();
        }
      </script>
    </head>
    <body>
      <h1>Network Configuration</h1>
      ${message ? `<div class="message ${message.includes('Error') ? 'error' : 'success'}">${message}</div>` : ''}
      <form method="POST" action="/">
        <div class="form-group">
          <label for="jace_ip">JACE IP Address:</label>
          <input
            type="text"
            id="jace_ip"
            name="jace_ip"
            pattern="^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"
            value="${currentValues.jace_ip}"
            required
          />
        </div>
        <div class="form-group">
          <label for="gateway">Gateway:</label>
          <input
            type="text"
            id="gateway"
            name="gateway"
            pattern="^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"
            value="${currentValues.gateway}"
            required
          />
        </div>
        <div class="form-group">
          <label for="touchscreen_ip">Touchscreen IP Address:</label>
          <input
            type="text"
            id="touchscreen_ip"
            name="touchscreen_ip"
            pattern="^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"
            value="${currentValues.touchscreen_ip}"
            required
          />
        </div>
        <div class="button-group">
          <button type="submit">Save Configuration</button>
          <button type="button" id="network-status-btn" class="secondary" onclick="toggleNetworkStatus()">Show Network Status</button>
          <button type="button" id="refresh-status-btn" class="secondary" onclick="refreshNetworkStatus()" style="display: none;">Refresh Network Status</button>
        </div>
      </form>
      <div id="network-status" class="network-status" style="display: none;"></div>
    </body>
    </html>
  `
}

const validateIpAddress = (ip: string): boolean => {
    const ipRegex = /^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$/
    return ipRegex.test(ip)
}

const generateNetworkConfig = (touchscreenIp: string, gateway: string): string => {
    // Generate NetworkManager keyfile format
    return `[connection]
id=eth0
type=ethernet
interface-name=eth0

[ethernet]

[ipv4]
address1=${touchscreenIp}/24
gateway=${gateway}
dns=1.1.1.1;
method=manual

[ipv6]
method=disabled
`
}

const saveConfiguration = async (config: IpConfig): Promise<void> => {
    try {
        // Ensure config directory exists
        await Deno.mkdir(APP_CONFIG_DIR, {recursive: true})

        let configs: IpConfig[] = []

        try {
            const existingData = await Deno.readTextFile(CONFIG_FILE)
            configs = JSON.parse(existingData)
        } catch {
            // File doesn't exist yet, start with empty array
        }

        configs.unshift(config)

        await Deno.writeTextFile(CONFIG_FILE, JSON.stringify(configs, null, 2))

        // Generate and save the network configuration to staging directory
        const networkConfig = generateNetworkConfig(config.touchscreen_ip, config.gateway)
        const configId = `eth0_${Date.now()}`
        const stagingFile = `${STAGING_PENDING_DIR}/${configId}.nmconnection`

        // Ensure staging directory exists (but don't create if system hasn't set it up)
        try {
            await Deno.stat(STAGING_PENDING_DIR)
        } catch {
            throw new Error('Network staging directory not available. System may not be properly configured.')
        }

        // Write configuration to staging directory with atomic operation
        const tempFile = `${stagingFile}.tmp`
        await Deno.writeTextFile(tempFile, networkConfig)
        await Deno.rename(tempFile, stagingFile)

        // Wait briefly for processing and check status
        await new Promise(resolve => setTimeout(resolve, 1000))

        try {
            const statusFile = `${STAGING_STATUS_DIR}/${configId}.status`
            const status = await Deno.readTextFile(statusFile)
            if (status.includes('FAILED')) {
                throw new Error(`Network configuration failed: ${status}`)
            }
        } catch {
            // Status file may not exist yet, which is ok for now
        }
    } catch (error) {
        throw new Error(`Failed to save configuration: ${error instanceof Error ? error.message : String(error)}`)
    }
}

app.get('/', async (c) => {
    const currentValues = await parseNetworkConfig()
    return c.html(generateHtmlForm(currentValues))
})

app.post('/', async (c) => {
    try {
        const body = await c.req.parseBody()
        const touchscreen_ip = body.touchscreen_ip as string
        const gateway = body.gateway as string
        const jace_ip = body.jace_ip as string

        if (!touchscreen_ip || !gateway || !jace_ip) {
            const currentValues = await parseNetworkConfig()
            return c.html(generateHtmlForm(currentValues, 'Error: All fields are required'), 400)
        }

        if (!validateIpAddress(touchscreen_ip) || !validateIpAddress(gateway) || !validateIpAddress(jace_ip)) {
            const currentValues = await parseNetworkConfig()
            return c.html(generateHtmlForm(currentValues, 'Error: Invalid IP address format'), 400)
        }

        const config: IpConfig = {
            touchscreen_ip,
            gateway,
            jace_ip,
            timestamp: new Date().toISOString()
        }

        await saveConfiguration(config)

        const currentValues = await parseNetworkConfig()
        return c.html(generateHtmlForm(currentValues, 'Configuration saved successfully!'))
    } catch (error) {
        const currentValues = await parseNetworkConfig()
        return c.html(generateHtmlForm(currentValues, `Error: ${error instanceof Error ? error.message : String(error)}`), 500)
    }
})

app.get('/network-status', async (c) => {
    try {
        const command = new Deno.Command('ifconfig', {
            stdout: 'piped',
            stderr: 'piped',
        })

        const {code, stdout, stderr} = await command.output()

        if (code !== 0) {
            const errorText = new TextDecoder().decode(stderr)
            return c.json({error: `ifconfig failed: ${errorText}`}, 500)
        }

        const output = new TextDecoder().decode(stdout)
        return c.json({output})
    } catch (error) {
        return c.json({error: `Failed to execute ifconfig: ${error instanceof Error ? error.message : String(error)}`}, 500)
    }
})

Deno.serve(app.fetch)
