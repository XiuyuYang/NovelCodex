import copy,importlib.util,json,tempfile,unittest
from pathlib import Path
sp=importlib.util.spec_from_file_location('delta',str(Path(__file__).with_name('apply_patch.py')));m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
class Tests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.p=Path(self.t.name);self.c=self.p/'current.json';self.q=self.p/'patch.json'
  self.s=dict(version=1,events=[dict(id='E1',text='甲给乙粮食。'),dict(id='E2',text='乙答应帮忙。')],characters=[dict(id='C1',name='甲',facts=[dict(text='送粮',evidence=[dict(event_id='E1',quote='甲给乙粮食')])])],world=[],dependencies=[dict(id='D1',cause='E1',effect='E2')],foreshadowing=[])
  self.c.write_text(json.dumps(self.s,ensure_ascii=False));self.raw=self.c.read_bytes()
 def tearDown(self):self.t.cleanup()
 def patch(self,ops):return dict(base_version=1,base_sha256=m.digest(self.raw),operations=ops)
 def write(self,p):self.q.write_text(json.dumps(p,ensure_ascii=False))
 def replace(self,text):return dict(op='replace',collection='events',id='E1',value=dict(id='E1',text=text))
 def reject(self,p):
  self.write(p)
  with self.assertRaises((ValueError,KeyError,TypeError)):m.apply(self.c,self.q)
  self.assertEqual(self.raw,self.c.read_bytes())
 def test_valid_and_archive(self):
  self.write(self.patch([self.replace('甲给乙粮食。乙保存了种子。')]))
  r=m.apply(self.c,self.q);s=m.read_json(self.c)
  self.assertEqual(s['version'],2);self.assertEqual(s['characters'],self.s['characters']);self.assertEqual(Path(r['history']).read_bytes(),self.raw)
 def test_stale(self):
  p=self.patch([self.replace('甲给乙粮食。')]);p['base_version']=0;self.reject(p)
 def test_hash(self):
  p=self.patch([self.replace('甲给乙粮食。')]);p['base_sha256']='wrong';self.reject(p)
 def test_quote_in_unchanged_card(self):self.reject(self.patch([self.replace('甲没有送粮。')]))
 def test_dangling_dependency(self):self.reject(self.patch([dict(op='remove',collection='events',id='E2')]))
 def test_duplicate_target(self):self.reject(self.patch([self.replace('甲给乙粮食。')]*2))
 def test_add_order(self):
  self.write(self.patch([dict(op='add',collection='events',id='E3',after='E1',value=dict(id='E3',text='甲离开。'))]));m.apply(self.c,self.q);self.assertEqual([e['id'] for e in m.read_json(self.c)['events']],['E1','E3','E2'])
 def test_dry_run(self):
  self.write(self.patch([self.replace('甲给乙粮食。乙保存种子。')]));m.apply(self.c,self.q,True);self.assertEqual(self.raw,self.c.read_bytes());self.assertFalse((self.p/'history').exists())
 def test_synced_card(self):
  card=dict(id='C1',name='甲',facts=[dict(text='送药',evidence=[dict(event_id='E1',quote='甲给乙药')])])
  self.write(self.patch([self.replace('甲给乙药。'),dict(op='replace',collection='characters',id='C1',value=card)]));m.apply(self.c,self.q);self.assertEqual(m.read_json(self.c)['characters'][0],card)
 def test_unknown_field(self):
  p=self.patch([self.replace('甲给乙粮食。')]);p['full_state']={};self.reject(p)
 def test_replay(self):
  self.write(self.patch([self.replace('甲给乙粮食。乙保存种子。')]));m.apply(self.c,self.q);raw=self.c.read_bytes()
  with self.assertRaises(ValueError):m.apply(self.c,self.q)
  self.assertEqual(raw,self.c.read_bytes())
if __name__=='__main__':unittest.main(verbosity=2)
