import asyncio
import zendriver as zd
from flask import Flask, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

@app.route('/api/get_html', methods=['POST'])
async def get_html():
    body = request.get_json(force=True)
    url = body['url']
    
    try:
        browser = await zd.start(headless=True, no_sandbox=True)
        page = await browser.get(url)
        await page
        await page.wait(2)
        html = await page.get_content()
        await browser.stop()
        return {'html': html}
    except Exception as e:
        return {'error': str(e)}, 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
