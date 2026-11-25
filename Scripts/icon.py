# Generate an opaque, full-bleed 1024px iOS Home Screen icon.
import math, struct, zlib, json
from pathlib import Path
n = 1024
out = Path("App/Assets.xcassets/AppIcon.appiconset")
out.mkdir(parents=True, exist_ok=True)
(out.parent / "Contents.json").write_text(json.dumps({"info":{"author":"xcode","version":1}}))
(out / "Contents.json").write_text(json.dumps({"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}))
def clamp(v): return max(0,min(1,v))
def mix(a,b,t): return tuple(x*(1-t)+y*t for x,y in zip(a,b))
rows = bytearray()
for y in range(n):
    rows.append(0)
    for x in range(n):
        t = clamp((x*.38+y*.72)/1126)
        rgb = mix((247,250,255),(100,157,246),t)
        glow = .46*math.exp(-((x-185)**2+(y-125)**2)/(2*360**2))
        rgb = mix(rgb,(255,255,255),glow)
        # A single solid, compact black Dynamic Island silhouette.
        sd = math.hypot(max(abs(x-512)-174,0),y-512)-98
        shadow = .22*math.exp(-max(0,math.hypot(max(abs(x-512)-174,0),y-535)-98)**2/(2*29**2))
        rgb = mix(rgb,(26,44,82),shadow)
        rgb = mix(rgb,(82,101,132),clamp(1.5-sd)*.92)
        rgb = mix(rgb,(0,0,0),clamp(.5-sd))
        rows.extend(round(v) for v in rgb)
def chunk(t,b):
    return struct.pack(">I",len(b))+t+b+struct.pack(">I",zlib.crc32(t+b)&0xffffffff)
(out/"AppIcon.png").write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",n,n,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(rows,9))+chunk(b"IEND",b""))
