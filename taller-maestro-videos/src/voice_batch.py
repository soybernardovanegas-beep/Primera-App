"""Una llamada de TTS por video; la pista se parte en frases por los N-1 silencios más largos."""
import sys, os, re, hashlib, subprocess, wave, array
sys.path.insert(0, os.path.dirname(__file__))
from plan import VIDEOS
from tts import tts
os.makedirs('tmp/phr', exist_ok=True)
def base(t): return 'tmp/phr/' + hashlib.md5(t.encode()).hexdigest()[:12]
def dur(p): return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',p]))

def split(full, n):
    """devuelve n tramos (t0,t1) cortando en los n-1 silencios más largos"""
    err = subprocess.run(['ffmpeg','-i',full,'-af','silencedetect=noise=-38dB:d=0.12','-f','null','-'],capture_output=True,text=True).stderr
    st = [float(x) for x in re.findall(r'silence_start: ([\d.]+)', err)]
    en = [float(x) for x in re.findall(r'silence_end: ([\d.]+)', err)]
    total = dur(full)
    gaps = [(e - s, (s + e) / 2) for s, e in zip(st, en) if s > 0.3 and e < total - 0.1]
    cuts = sorted(m for _, m in sorted(gaps, reverse=True)[:n - 1])
    if len(cuts) < n - 1: raise RuntimeError('no se encontraron %d silencios' % (n - 1))
    b = [0] + cuts + [total]
    return list(zip(b, b[1:]))

def run(vid):
    sc = VIDEOS[vid]['scenes']
    if all(os.path.exists(base(s['voz']) + '.wav') for s in sc): return True
    full = 'tmp/%s_full.wav' % vid
    if not os.path.exists(full):
        if not tts('\n\n'.join(s['voz'] for s in sc), full): return False
    for s, (a, b) in zip(sc, split(full, len(sc))):
        subprocess.run(['ffmpeg','-v','error','-y','-ss','%.3f'%a,'-to','%.3f'%b,'-i',full,base(s['voz'])+'.wav'],check=True)
    return True

if __name__ == '__main__':
    for v in (sys.argv[1:] or VIDEOS): print(v, run(v))
