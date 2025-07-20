import asyncio
import zendriver as zd
from flask import Flask, request

app = Flask(__name__)

@app.route('/api/get_html', methods=['POST'])
async def get_html():
    body = request.get_json(force=True)
    url = body['url']
    
    try:
        page = await load_page(url)
        html = await scrape_html(page)
        return {'html': html}
    except Exception as e:
        return {'error': str(e)}, 500

async def scrape_html(page: zd.Tab):
    return await page.get_content()

async def load_page(url: str):
    browser = await zd.start(headless=True)
    page = await browser.get(url)
    await page.wait(2)

    return page;



if __name__ == '__main__':
    app.run(debug=True)