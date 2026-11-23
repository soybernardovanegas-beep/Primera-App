"""Una llamada de TTS por video; la pista se parte en frases por los N-1 silencios más largos."""
import sys, os, re, hashlib, subprocess, wave, array
sys.path.insert(0, os.path.dirname(__file__))
from plan import VIDEOS
from tts import tts
os.makedirs('tmp/phr', exist_ok=True)
def base(t): return 'tmp/phr/' + hashlib.md5(t.encode()).hexdigest()[:12]
def dur(p): return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',p]))

def split(full, n, texts=None):
    """n tramos: corta en el silencio más cercano a la posición proporcional (por caracteres) de cada frase"""
    err = subprocess.run(['ffmpeg','-i',full,'-af','silencedetect=noise=-38dB:d=0.1','-f','null','-'],capture_output=True,text=True).stderr
    st = [float(x) for x in re.findall(r'silence_start: ([\d.]+)', err)]
    en = [float(x) for x in re.findall(r'silence_end: ([\d.]+)', err)]
    total = dur(full)
    mids = [((s + e) / 2, e - s) for s, e in zip(st, en) if s > 0.3 and e < total - 0.1]
    if len(mids) < n - 1: raise RuntimeError('no se encontraron %d silencios' % (n - 1))
    w = [len(t) for t in texts] if texts else [1] * n
    # el audio tiene pausas iniciales/finales: se reparte sobre el tramo hablado
    t0 = min(st[0], 0) if False else 0.0
    cuts, acc, last = [], 0, 0.0
    for i in range(n - 1):
        acc += w[i]; exp = total * acc / sum(w)
        cand = [m for m in mids if m[0] > last + 0.4]
        if not cand: raise RuntimeError('faltan silencios')
        near = [m for m in cand if abs(m[0] - exp) <= 1.0] or [min(cand, key=lambda m: abs(m[0] - exp))]
        c = max(near, key=lambda m: m[1] - 0.3 * abs(m[0] - exp))[0]; cuts.append(c); last = c
    b = [0] + cuts + [total]
    return list(zip(b, b[1:]))

CUTS = {'C3': [3.0, 7.3, 10.2, 13.7], 'A2': [2.5, 5.2, 7.2]}  # cortes revisados a mano sobre las voces nuevas

def run(vid):
    sc = VIDEOS[vid]['scenes']
    if all(os.path.exists(base(s['voz']) + '.wav') for s in sc): return True
    full = 'tmp/%s_full.wav' % vid
    if not os.path.exists(full):
        if not tts('\n\n'.join(s['voz'] for s in sc), full): return False
    if vid in CUTS:
        bs = [0] + CUTS[vid] + [dur(full)]; spans = list(zip(bs, bs[1:]))
    else: spans = split(full, len(sc), [x['voz'] for x in sc])
    for s, (a, b) in zip(sc, spans):
        subprocess.run(['ffmpeg','-v','error','-y','-ss','%.3f'%a,'-to','%.3f'%b,'-i',full,base(s['voz'])+'.wav'],check=True)
    return True

if __name__ == '__main__':
    for v in (sys.argv[1:] or VIDEOS): print(v, run(v))
