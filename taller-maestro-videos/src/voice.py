import sys,hashlib,os,json
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0,os.path.dirname(__file__))
from plan import VIDEOS
from tts import tts
os.makedirs('tmp/phr',exist_ok=True)
def path(t): return 'tmp/phr/'+hashlib.md5(t.encode()).hexdigest()[:12]+'.wav'
ids=sys.argv[1:] or list(VIDEOS)
jobs=[s['voz'] for k,v in VIDEOS.items() if k in ids for s in v['scenes']]
def run(t):
    p=path(t)
    if os.path.exists(p): return True
    return tts(t,p)
with ThreadPoolExecutor(2) as ex: res=list(ex.map(run,jobs))
print(sum(res),'/',len(jobs))
