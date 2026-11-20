#!/usr/bin/env python3
"""Launch real dedicated server + 9 ENet clients; Supabase boundaries are fixtures."""
import subprocess,os,sys,time,json,pathlib
project=pathlib.Path(__file__).resolve().parents[1]
godot=str(pathlib.Path(sys.argv[1]).resolve())
out=pathlib.Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,OXENWAR_SERVER_SECRET='capacity-fixture-only',OXENWAR_CAPACITY_DIR=str(out))
env.pop('OXENWAR_TRANSPORT',None)
processes=[];files=[]
def launch(script,name,args=()):
 f=open(out/(name+'.log'),'w');files.append(f)
 p=subprocess.Popen([godot,'--headless','--path',str(project),'--script',script,'--',*args],stdout=f,stderr=subprocess.STDOUT,env=env);processes.append(p)
try:
 launch('tests/online/online_server.gd','server')
 for _ in range(100):
  if 'ONLINE_SERVER_READY' in (out/'server.log').read_text():break
  time.sleep(.1)
 else:raise RuntimeError('server startup failed')
 for i in range(9):launch('tests/online/capacity_client.gd','client'+str(i),['--role='+str(i)])
 deadline=time.monotonic()+55
 while time.monotonic()<deadline and len(list(out.glob('[0-8].json')))<9:time.sleep(.2)
 results=[json.loads((out/(str(i)+'.json')).read_text()) for i in range(9)]
 groups={}
 for r in results:
  assert r['authenticated'] and r['snapshots']>20,r
  code=r['room']['code'];groups.setdefault(code,[]).append(r)
  assert r['room_count']==1,r
 assert sorted(map(len,groups.values()))==[1,8],{k:len(v) for k,v in groups.items()}
 for code,rs in groups.items():
  for r in rs:assert r['others']==len(rs)-1,(code,r['role'],r['others'])
  for r in rs:
   assert r['reload'],('missing local reload',r['role'])
   assert r['remote_reload']==(len(rs)>1),('reload isolation',r['role'])
 assert sum(r['moved'] for r in results)>=6,'too few authoritative movement confirmations'
 for f in out.glob('*.log'):assert 'SCRIPT ERROR' not in f.read_text(),f
 summary={'status':'PASS','clients':9,'room_sizes':sorted(map(len,groups.values())),'movement_confirmed':sum(r['moved'] for r in results),'transport':'ENet UDP localhost','auth':'fixture ticket redemption','persistence':'fixture; no Supabase writes'}
 (out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary))
finally:
 for p in processes:p.terminate()
 for p in processes:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for f in files:f.close()
