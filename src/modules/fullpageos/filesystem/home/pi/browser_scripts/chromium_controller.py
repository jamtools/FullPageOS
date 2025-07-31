import json
import os
import subprocess
import sys
import time
import traceback
import urllib.request
import urllib.error
from watchdog.observers.polling import PollingObserver
from watchdog.events import FileSystemEventHandler

import pychrome


class IPConfigHandler(FileSystemEventHandler):
    def __init__(self, controller):
        self.controller = controller
        
    def on_modified(self, event):
        if not event.is_directory and event.src_path.endswith('ip_config.json'):
            print(f"IP config file modified: {event.src_path}")
            self.controller.check_jace_ip()


class ChromiumController():
    def __init__(self):
        self.env = os.environ.copy()

        self.base_dir = "/config" if "RUNNING_IN_DOCKER" in self.env else "/boot"
        self.ip_config_file = "/home/pi/apps/ip_configurator/ip_config.json"
        self.current_jace_url = "http://localhost:8000"  # Default fallback


        try:
            self.mute_time = int(sys.argv[-1])
        except ValueError:
            self.mute_time = 0

        self.mute_time_left = -1

        self.browser = pychrome.Browser(url="http://127.0.0.1:9222")
        self.tab = self.browser.list_tab()[0]
        self.initial_load = False

        self.tab.Page.frameNavigated = self._response_received
        self.tab.Network.loadingFailed = self._loading_failed

        self.tab.start()
        self.tab.DOM.enable()
        self.tab.Page.enable()
        self.tab.Network.enable()
        
        # Set up file watching for IP config changes
        self.setup_ip_config_monitoring()
        
        # Initial check of jace_ip
        self.check_jace_ip()
        
        self._load_page()

    def setup_ip_config_monitoring(self):
        """Set up file monitoring for IP config changes"""
        try:
            event_handler = IPConfigHandler(self)
            self.observer = PollingObserver()
            self.observer.schedule(event_handler, os.path.dirname(self.ip_config_file), recursive=False)
            self.observer.start()
        except Exception as e:
            print(f"Failed to setup IP config monitoring: {e}")
            self.observer = None
            
    def __del__(self):
        """Cleanup file observer"""
        if hasattr(self, 'observer') and self.observer:
            self.observer.stop()
            self.observer.join()
            
    def check_jace_ip(self):
        """Check if jace_ip is reachable and update current_jace_url"""
        previous_url = self.current_jace_url
        
        try:
            with open(self.ip_config_file, 'r') as f:
                configs = json.load(f)
                # Get the most recent config (first in array)
                config = configs[0] if configs else {}
                jace_ip = config.get('jace_ip', '')
                
            if jace_ip:
                # Try to connect to jace_ip
                test_url = f"http://{jace_ip}"
                try:
                    with urllib.request.urlopen(test_url, timeout=5) as response:
                        if response.getcode() == 200:
                            self.current_jace_url = test_url
                            print(f"JACE IP {jace_ip} is reachable, using {test_url}")
                        else:
                            raise urllib.error.HTTPError(test_url, response.getcode(), "Non-200 response", None, None)
                except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
                    print(f"Failed to connect to JACE IP {jace_ip}: {e}")
                    self.current_jace_url = "http://localhost:8000"
            else:
                # No jace_ip configured, use localhost
                self.current_jace_url = "http://localhost:8000"
                
        except Exception as e:
            print(f"Error checking IP config: {e}")
            self.current_jace_url = "http://localhost:8000"
            
        # If URL changed, navigate to new URL
        if previous_url != self.current_jace_url:
            print(f"URL changed from {previous_url} to {self.current_jace_url}, navigating...")
            self._load_page()

    def run_forever(self):
        while True:
            if self.mute_time_left > 0:
                self.mute_time_left -= 1
            elif self.mute_time_left == 0:
                subprocess.run(['amixer', 'set', 'PCM', 'unmute'], check=True)

            time.sleep(1)

    def _response_received(self, **kwargs):
        doc_root = self.tab.DOM.getDocument()['root']

        if not doc_root['children']:
            return

        if not doc_root['children'][-1]['frameId'] == kwargs['frame']['id']:
            return

        if self.mute_time > 0:
            subprocess.run(['amixer', 'set', 'PCM', 'mute'], check=True)

            self.mute_time_left = self.mute_time

        if self.initial_load:
            self.initial_load = False

    def _loading_failed(self, **kwargs):
        # We only care about the main page loading, not of any subelement
        if (kwargs['type'] != 'Document' or self.tab.DOM.getDocument()['root']['children'][-1]['frameId'] != kwargs['frameId']):
            return

        time.sleep(5)
        self._load_page()

    def _load_page(self):
        # Use dynamic jace URL instead of cycling through kiosk_urls
        self.initial_load = True
        self.tab.Page.navigate(url=self.current_jace_url)


while True:
    try:
        chromium_controller = ChromiumController()
        chromium_controller.run_forever()
    except:
        print(traceback.format_exc())
        time.sleep(10)
