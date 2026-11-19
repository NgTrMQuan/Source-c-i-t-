#!/usr/bin/env python3
"""Kiểm tra toàn bộ link tải trong data.json và ghi kết quả ra link-status.json.

Chạy:  python tools/check_links.py            (kiểm tra tất cả)
       python tools/check_links.py --only-new (chỉ kiểm tra link chưa có trong link-status.json)

Kết quả cho mỗi URL:
  {"ok": true|false|null, "code": 200, "size": 123456789, "checked": "2026-11-19", "error": "..."}
  ok = null nghĩa là không kết luận được (máy chủ chặn, hết thời gian chờ…), trang sẽ không báo hỏng.

Chỉ dùng thư viện chuẩn của Python để chạy được trên GitHub Actions mà không cần cài thêm.
"""
import json, sys, datetime, concurrent.futures as cf, urllib.request, urllib.error, socket, re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'data.json')
OUT = os.path.join(ROOT, 'link-status.json')
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36'
TIMEOUT = 25

def probe(url):
    """Thử HEAD trước; nếu máy chủ không hỗ trợ thì GET 1 byte (Range) để không tải cả file."""
    last = None
    for method, headers in (('HEAD', {}), ('GET', {'Range': 'bytes=0-0'})):
        req = urllib.request.Request(url, method=method, headers={'User-Agent': UA, **headers})
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
                code = r.status
                size = None
                cr = r.headers.get('Content-Range')          # bytes 0-0/123456
                if cr and '/' in cr and cr.rsplit('/', 1)[1].isdigit():
                    size = int(cr.rsplit('/', 1)[1])
                elif r.headers.get('Content-Length', '').isdigit() and method == 'HEAD':
                    size = int(r.headers['Content-Length'])
                ctype = (r.headers.get('Content-Type') or '').lower()
                # Một số máy chủ trả 200 kèm trang HTML báo lỗi thay vì file cài đặt
                if 'text/html' in ctype and not re.search(r'\.(html?|aspx?)($|\?)', url, re.I):
                    return {'ok': False, 'code': code, 'error': 'Trả về trang HTML thay vì file'}
                return {'ok': True, 'code': code, 'size': size}
        except urllib.error.HTTPError as e:
            last = {'ok': False, 'code': e.code, 'error': f'HTTP {e.code}'}
            if e.code in (403, 405, 501) and method == 'HEAD':
                continue                                   # thử lại bằng GET
            if e.code in (401, 403, 429) or e.code >= 500:
                last['ok'] = None                         # bị chặn/tạm lỗi: chưa kết luận hỏng
            return last
        except (urllib.error.URLError, socket.timeout, TimeoutError, ConnectionError) as e:
            reason = getattr(e, 'reason', e)
            last = {'ok': None, 'code': None, 'error': str(reason)[:120]}
            if isinstance(reason, socket.gaierror):          # tên miền không còn tồn tại
                last['ok'] = False
            if method == 'HEAD':
                continue
            return last
    return last or {'ok': None, 'code': None, 'error': 'Không rõ'}

def main():
    only_new = '--only-new' in sys.argv
    data = json.load(open(DATA, encoding='utf-8'))
    old = {}
    if os.path.exists(OUT):
        try: old = json.load(open(OUT, encoding='utf-8')).get('links', {})
        except Exception: old = {}
    urls = sorted({l['url'] for p in data for v in p['versions'] for l in v['links']})
    todo = [u for u in urls if not (only_new and u in old)]
    today = datetime.date.today().isoformat()
    res = {u: old[u] for u in urls if u in old}             # bỏ link không còn trong data.json
    print(f'Kiểm tra {len(todo)}/{len(urls)} link…', flush=True)
    with cf.ThreadPoolExecutor(12) as ex:
        for u, r in zip(todo, ex.map(probe, todo)):
            prev = old.get(u, {})
            r['checked'] = today
            if r.get('ok') is None and prev.get('size') and not r.get('size'):
                r['size'] = prev['size']                      # giữ dung lượng biết từ lần trước
            if r.get('ok') is False and prev.get('ok') is False:
                r['since'] = prev.get('since', prev.get('checked', today))
            elif r.get('ok') is False:
                r['since'] = today
            res[u] = {k: v for k, v in r.items() if v is not None or k == 'ok'}
            mark = {True: 'OK  ', False: 'HỎNG', None: '??  '}[r.get('ok')]
            print(mark, r.get('code'), u[:110], flush=True)
    summary = {'ok': sum(1 for r in res.values() if r.get('ok') is True),
               'broken': sum(1 for r in res.values() if r.get('ok') is False),
               'unknown': sum(1 for r in res.values() if r.get('ok') is None)}
    json.dump({'updated': today, 'summary': summary, 'links': res}, open(OUT, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1, sort_keys=True)
    print('Xong:', summary)

if __name__ == '__main__':
    main()
