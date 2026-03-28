import base64

for i in range(1, 5):
    with open('splash_%d.png' % i, 'rb') as f:
        data = base64.b64encode(f.read()).decode()
    print('DATA_%d_START' % i)
    print(data[:50])  # just verify it's valid
    print('DATA_%d_END' % i)
    print('Size: %d chars' % len(data))
