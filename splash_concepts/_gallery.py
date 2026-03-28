import base64
imgs = []
for i in range(1, 5):
    with open('splash_%d.png' % i, 'rb') as f:
        imgs.append('data:image/png;base64,' + base64.b64encode(f.read()).decode())

html = '<html><body style="background:#1a1a1a;display:flex;flex-wrap:wrap;gap:10px;padding:10px;justify-content:center">'
for i, img in enumerate(imgs):
    html += '<div style="text-align:center"><img src="%s" style="width:400px;border-radius:12px"><p style="color:white;font-size:18px">Option %d</p></div>' % (img, i + 1)
html += '</body></html>'

with open('gallery.html', 'w') as f:
    f.write(html)
print('Gallery written')
