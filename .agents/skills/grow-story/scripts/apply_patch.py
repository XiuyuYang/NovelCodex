"""Apply reviewed, version-guarded story deltas. Python 3; POSIX file locking."""
import argparse, copy, fcntl, hashlib, json, os, tempfile
from pathlib import Path
COLLECTIONS = ('events','characters','world','dependencies','foreshadowing')

def require(ok, message):
    if not ok: raise ValueError(message)

def digest(raw): return hashlib.sha256(raw).hexdigest()

def read_json(path):
    def pairs(items):
        out={}
        for k,v in items:
            require(k not in out, 'duplicate JSON key: '+k); out[k]=v
        return out
    return json.loads(path.read_bytes(), object_pairs_hook=pairs)

def validate(state):
    require(type(state.get('version')) is int and state['version']>=1,'invalid version')
    for c in COLLECTIONS:
        require(isinstance(state.get(c),list),'missing list: '+c)
        ids=[x.get('id') for x in state[c]]
        require(all(isinstance(i,str) and i for i in ids),'missing IDs: '+c)
        require(len(ids)==len(set(ids)),'duplicate IDs: '+c)
    events={x['id']:x for x in state['events']}
    for e in events.values():
        require(isinstance(e.get('text'),str) and bool(e['text'].strip()),'empty event')
    for d in state['dependencies']:
        require(d.get('cause') in events and d.get('effect') in events,'dangling dependency')
    def walk(x):
        if isinstance(x,dict):
            if 'evidence' in x:
                require(isinstance(x['evidence'],list) and bool(x['evidence']),'empty evidence')
                for r in x['evidence']:
                    require(isinstance(r,dict),'invalid evidence')
                    i,q=r.get('event_id'),r.get('quote')
                    require(i in events and isinstance(q,str) and bool(q.strip()) and q in events[i]['text'],'invalid source quote: '+str(i))
            for v in x.values(): walk(v)
        elif isinstance(x,list):
            for v in x: walk(v)
    walk(state)

def merge(state, patch, sha):
    require(set(patch)=={'base_version','base_sha256','operations'},'unexpected or missing patch fields')
    require(patch['base_version']==state['version'] and patch['base_sha256']==sha,'stale base version or hash')
    require(isinstance(patch['operations'],list) and bool(patch['operations']),'empty operations')
    out=copy.deepcopy(state); touched=set(); retired=set(out.get('retired_event_ids',[]))
    for op in patch['operations']:
        kind,c,i=op.get('op'),op.get('collection'),op.get('id')
        require(c in COLLECTIONS and isinstance(i,str) and i,'invalid target')
        require((c,i) not in touched,'duplicate target in patch');touched.add((c,i))
        rows=out[c]; found=next((n for n,x in enumerate(rows) if x['id']==i),None)
        if kind in ('add','replace'):
            allowed={'op','collection','id','value'} | ({'after'} if kind=='add' and c=='events' else set())
            require(set(op)<=allowed and {'op','collection','id','value'}<=set(op),'invalid operation fields')
            value=op['value'];require(isinstance(value,dict) and value.get('id')==i,'value ID mismatch')
            if kind=='replace':
                require(found is not None,'replace missing target');rows[found]=copy.deepcopy(value)
            else:
                require(found is None,'add existing target')
                require(not(c=='events' and i in retired),'cannot reuse retired event ID')
                if c=='events':
                    require('after' in op,'event add requires after (null for beginning)')
                    after=op['after']; pos=next((n for n,x in enumerate(rows) if x['id']==after),None)
                    require(after is None or pos is not None,'missing order anchor')
                    rows.insert(0 if after is None else pos+1,copy.deepcopy(value))
                else: rows.append(copy.deepcopy(value))
        elif kind=='remove':
            require(set(op)=={'op','collection','id'},'invalid remove fields')
            require(found is not None,'remove missing target');rows.pop(found)
            if c=='events':retired.add(i)
        else: raise ValueError('unsupported operation')
    out['retired_event_ids']=sorted(retired);out['version']+=1
    validate(out); return out

def apply(current, patch_path, dry_run=False):
    current=Path(current); patch=read_json(Path(patch_path))
    with open(str(current)+'.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        raw=current.read_bytes();state=read_json(current);validate(state)
        out=merge(state,patch,digest(raw))
        if dry_run:return {'status':'validated','version':out['version'],'operations':len(patch['operations'])}
        history=current.parent/'history';history.mkdir(exist_ok=True)
        archive=history/(f"v{state['version']}-"+digest(raw)+'.json')
        if archive.exists():require(archive.read_bytes()==raw,'archive conflict')
        else:
            with archive.open('xb') as f:f.write(raw);f.flush();os.fsync(f.fileno())
        fd,tmp=tempfile.mkstemp(dir=current.parent,prefix='.story-')
        try:
            with os.fdopen(fd,'w',encoding='utf-8') as f:
                json.dump(out,f,ensure_ascii=False,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
            os.replace(tmp,current)
            directory=os.open(current.parent,os.O_RDONLY)
            try:os.fsync(directory)
            finally:os.close(directory)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
        return {'status':'committed','version':out['version'],'operations':len(patch['operations']),'history':str(archive)}

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('current');a.add_argument('patch');a.add_argument('--dry-run',action='store_true');args=a.parse_args()
    try: print(json.dumps(apply(args.current,args.patch,args.dry_run),ensure_ascii=False))
    except (ValueError,KeyError,TypeError,OSError) as exc:a.exit(1,'REJECTED: '+str(exc)+'\n')
