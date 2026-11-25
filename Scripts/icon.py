# Generate an opaque 1024px app icon without external dependencies.
import math, struct, zlib, json
from pathlib import Path
n = 1024
out = Path("App/Assets.xcassets/AppIcon.appiconset")
out.mkdir(parents=True, exist_ok=True)
(out.parent / "Contents.json").write_text(json.dumps({"info":{"author":"xcode","version":1}}))
(out / "Contents.json").write_text(json.dumps({"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}))
rows = bytearray()
for y in range(n):
    rows.append(0)
    for x in range(n):
        glow = math.exp(-((x-330)**2+(y-180)**2)/(2*400**2))
        r,g,b = 14+int(38*glow), 19+int(52*glow), 34+int(85*glow)
        d = math.hypot(max(abs(x-512)-154,0), y-512)
        # Rounded black pill, with a fine metallic edge.
        a = max(0,min(1,100.5-d))
        edge = max(0,min(1,103.5-d))
        r,g,b = [round(v*(1-edge)+c*edge) for v,c in zip((r,g,b),(80,94,119))]
        r,g,b = [round(v*(1-a)+c*a) for v,c in zip((r,g,b),(0,0,0))]
        rows.extend((r,g,b))
def chunk(t,b):
    return struct.pack(">I",len(b))+t+b+struct.pack(">I",zlib.crc32(t+b)&0xffffffff)
(out/"AppIcon.png").write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",n,n,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(rows,9))+chunk(b"IEND",b""))
