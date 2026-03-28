import base64
for i in range(1, 5):
    with open('splash_%d.png' % i, 'rb') as f:
        data = base64.b64encode(f.read()).decode()
    print('SPLASH_%d=' % i)
    # Just print size info
    import os
    sz = os.path.getsize('splash_%d.png' % i)
    print('  splash_%d.png: %d KB' % (i, sz // 1024))
