"""Serve the browser game locally. Press Ctrl+C to stop."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import webbrowser

DIRECTORY = Path(__file__).resolve().parent / "game"
HOST = "127.0.0.1"
PORT = 8765

if __name__ == "__main__":
    handler = partial(SimpleHTTPRequestHandler, directory=str(DIRECTORY))
    server = ThreadingHTTPServer((HOST, PORT), handler)
    url = f"http://{HOST}:{PORT}/index.html"
    print(f"Opening Galaxy Defender at {url}")
    print("Press Ctrl+C to stop the game server.")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local server.")
    finally:
        server.server_close()
