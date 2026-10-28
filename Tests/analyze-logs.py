from pathlib import Path
import re
root=Path(__file__).resolve().parent
for name in ['qa-natural.log','qa-default.log']:
 path=root/name
 if not path.exists(): continue
 text=path.read_text()
 plays=re.findall(r'PLAY (\S+) ordinal=(\d+)',text)
 drifts=[float(v) for v in re.findall(r'SYNC drift=([^\s]+)',text)]
 starts=[]; durations=[]
 for line in text.splitlines():
  if ' HOLD_BEGIN' in line: starts.append(float(line.split()[0]))
  elif ' HOLD_CANCEL' in line: starts=[]
  elif ' HOLD_COMPLETE' in line and starts:
   durations.append(float(line.split()[0])-starts[-1]); starts=[]
 print(name, 'play events',len(plays),'unique movies',len(set(v[0] for v in plays)), 'max sampled drift ms',max(drifts,default=0)*1000,'completed holds s',durations)
 assert not re.search(r' ERROR | STALL',text)
 assert all(t>=5-1e-6 for t in durations)
 if name=='qa-natural.log':
  assert len(plays)>=12
  for i in range(0,12,6): assert len(set(v[0] for v in plays[i:i+6]))==6
  assert plays[5][0]!=plays[6][0]
 if drifts: assert max(drifts)<0.1
