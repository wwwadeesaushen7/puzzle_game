"""Generate original ambient music and tactile sound effects; Python stdlib only."""
from pathlib import Path
import math, random, wave, struct
OUT=Path(__file__).resolve().parents[1]/'assets'/'audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050

def save(name,seconds,fn):
    data=bytearray()
    for i in range(int(seconds*RATE)):
        t=i/RATE
        data.extend(struct.pack('<h',int(max(-1,min(1,fn(t)))*26000)))
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data)

random.seed(71)
save('select',.25,lambda t:(math.sin(2*math.pi*520*t)*.2+random.uniform(-.04,.04))*math.exp(-t*25))
save('match',1.5,lambda t:sum(math.sin(2*math.pi*f*t)*math.exp(-t*(3+i)) for i,f in enumerate([523.25,659.25,783.99,1046.5]))*.12*min(1,t*80))
save('stone',.65,lambda t:(random.uniform(-.15,.15)+math.sin(t*150)*.06)*math.sin(t/.65*math.pi)**2)
save('victory',3,lambda t:sum(math.sin(2*math.pi*f*max(0,t-i*.17))*math.exp(-max(0,t-i*.17)*2)*(t>=i*.17) for i,f in enumerate([392,523.25,659.25,783.99,1046.5]))*.10)
# Integer cycle counts make the 32 second pad loop seamless.
save('ambient',32,lambda t:sum(math.sin(2*math.pi*round(f*32)/32*t+.08*math.sin(2*math.pi*t/32))*(.55+.2*math.sin(2*math.pi*t/32+i)) for i,f in enumerate([65.406,130.813,195.998,261.626,329.628]))*.033)
print('Generated five original PCM audio assets.')
