#!/usr/bin/env python3
"""Lấy link bộ cài từ Notion (OneCAD Vietnam / Source cài đặt) và bổ sung vào data.json.

Cấu trúc Notion đang dùng: trang "Source cài đặt" có các trang con, mỗi trang là một phần mềm
(vd. "Autocad Mechanical"), bên trong là một bảng 2 cột: cột 1 = năm/phiên bản, cột 2 = các link
(có thể ghi "Part 1:", "Part 2:" trước mỗi link).

Script CHỈ BỔ SUNG, không bao giờ xóa: phiên bản mới → thêm; link mới trong phiên bản đã có → thêm.
Phần mềm trên Notion chưa có trên trang web sẽ được thêm vào nhóm "Khác" để bạn tự xếp lại.

Cách dùng:
  1. Tạo integration tại https://www.notion.so/my-integrations → copy "Internal Integration Secret".
  2. Mở trang "Source cài đặt" trên Notion → ••• → Connections → thêm integration vừa tạo.
  3. Chạy:
       set NOTION_TOKEN=secret_xxx            (Windows)   |  export NOTION_TOKEN=secret_xxx (macOS/Linux)
       python tools/notion_sync.py            → chỉ xem khác biệt, không sửa gì
       python tools/notion_sync.py --write    → ghi vào data.json
  Hoặc trên GitHub: Settings → Secrets → Actions → thêm NOTION_TOKEN, rồi vào tab Actions →
  "Đồng bộ từ Notion" → Run workflow.
"""
import json, os, re, sys, urllib.request, urllib.error, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'data.json')
PARENT = os.environ.get('NOTION_PAGE_ID', '41ae71da0b3b8035bef9f046452d6ffd')  # "Source cài đặt"
TOKEN = os.environ.get('NOTION_TOKEN', '')

def api(path):
    req = urllib.request.Request('https://api.notion.com/v1/' + path, headers={
        'Authorization': 'Bearer ' + TOKEN, 'Notion-Version': '2022-06-28'})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        msg = e.read().decode('utf-8', 'ignore')[:300]
        sys.exit(f'Lỗi Notion API {e.code}: {msg}\n→ Kiểm tra NOTION_TOKEN và đã thêm integration vào trang "Source cài đặt" chưa.')

def children(block_id):
    out, cur = [], None
    while True:
        r = api(f'blocks/{block_id}/children?page_size=100' + (f'&start_cursor={cur}' if cur else ''))
        out += r['results']
        if not r.get('has_more'): return out
        cur = r['next_cursor']

def norm(s):
    s = unicodedata.normalize('NFD', s.lower()).replace('đ', 'd')
    return re.sub(r'[^a-z0-9]+', ' ', ''.join(c for c in s if unicodedata.category(c) != 'Mn')).strip()

def key(url):
    """So sánh link theo tên file (bỏ authparam) để không thêm trùng khi chỉ khác tham số."""
    return url.split('?')[0].rstrip('/').rsplit('/', 1)[-1].lower()

def parse_cell(rich):
    """Trả về [(label, url)] từ một ô bảng."""
    links, label, n = [], None, 0
    for t in rich:
        txt = t.get('plain_text', '')
        href = t.get('href') or (t.get('text', {}).get('link') or {}).get('url')
        m = re.search(r'(Part\s*\d+|Bộ cài|Web installer|Create Installer|32-bit|64-bit|macOS)\s*:?\s*$', txt, re.I)
        if href and href.startswith('http'):
            n += 1
            links.append(((label or f'Part {n}').strip(), href)); label = None
        elif m:
            label = m.group(1)
    if len(links) == 1 and links[0][0] == 'Part 1':
        links = [('Bộ cài', links[0][1])]
    return links

def year_of(v):
    m = re.match(r'\d{4}', v); return int(m.group()) if m else 0

def main():
    if not TOKEN: sys.exit('Thiếu NOTION_TOKEN. Xem hướng dẫn ở đầu file tools/notion_sync.py')
    write = '--write' in sys.argv
    data = json.load(open(DATA, encoding='utf-8'))
    index = {}
    for p in data:
        for name in [p['name'], *p.get('aliases', [])]:
            index.setdefault(norm(name), p)
    changes = 0
    for b in children(PARENT):
        if b['type'] != 'child_page': continue
        title = b['child_page']['title'].strip()
        p = index.get(norm(title))
        rows = []
        for t in children(b['id']):
            if t['type'] != 'table': continue
            for row in children(t['id']):
                cells = row.get('table_row', {}).get('cells', [])
                if len(cells) < 2: continue
                ver = ''.join(x.get('plain_text', '') for x in cells[0]).strip()
                links = parse_cell(cells[1])
                if ver and links: rows.append((ver, links))
        if not rows: continue
        if not p:
            print(f'+ Phần mềm mới từ Notion: {title} ({len(rows)} phiên bản) → nhóm "Khác"')
            p = {'name': title, 'icon': '📦', 'group': 'Khác', 'note': 'Thêm tự động từ Notion — cần xếp lại nhóm.', 'aliases': [], 'ring': False, 'versions': []}
            data.append(p); index[norm(title)] = p
        for ver, links in rows:
            v = next((x for x in p['versions'] if x['v'].strip().lower() == ver.lower()), None)
            if not v:
                v = {'v': ver, 'links': [{'label': l, 'url': u} for l, u in links]}
                i = next((k for k, x in enumerate(p['versions']) if year_of(x['v']) < year_of(ver)), len(p['versions']))
                p['versions'].insert(i, v); changes += 1
                print(f'  + {p["name"]} {ver}: thêm phiên bản ({len(links)} link)')
                continue
            have = {key(l['url']) for l in v['links']}
            for l, u in links:
                if key(u) not in have:
                    v['links'].append({'label': l, 'url': u}); have.add(key(u)); changes += 1
                    print(f'  + {p["name"]} {ver}: thêm link {l}')
    print(f'\n{changes} thay đổi.' + ('' if write or not changes else ' Chạy lại với --write để ghi vào data.json.'))
    if write and changes:
        json.dump(data, open(DATA, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
        print('Đã ghi data.json.')

if __name__ == '__main__':
    main()
