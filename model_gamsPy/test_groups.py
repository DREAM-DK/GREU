%reload_ext autoreload
%autoreload 2


def test():
  from global_container import Variable, Set, Group, Tag

  tag1 = Tag()
  tag2 = Tag()

  s = Set(name="s", records=["a", "b"])
  t = Set(name="t", records=[1, 2])
  v_s = Variable(name="v_s", domain=[s], tags=[tag1])
  v_s_t = Variable(name="v_s_t", domain=[s, t], tags=[tag2])

  g = Group()
  g += v_s['a']

  assert g.contains_any(v_s), "Group should contain v_s['a']"
  assert g.contains_all(v_s["a"]), "Group should contain v_s['a']"
  assert not g.contains_all(v_s), "Group should not contain v_s['b']"
  assert not g.contains_any(v_s['b']), "Group should not contain v_s['b']"
  
  g += v_s_t['a',t]
  assert g.contains_any(v_s_t), "Group should contain v_s_t['a',t]"
  assert g.contains_all(v_s_t['a',t]), "Group should contain v_s_t['a',t]"
  assert not g.contains_all(v_s_t), "Group should not contain v_s_t['b',t]"
  assert not g.contains_any(v_s_t['b',t]), "Group should not contain v_s_t['b',t]"

  g2 = Group()
  g2 += v_s['b']
  g += g2
  assert g.contains_any(v_s), "Group should contain v_s"
  assert g.contains_all(v_s), "Group should contain all v_s"
  assert g.contains_all(v_s["a"]), "Group should contain v_s['a']"
  assert g.contains_all(v_s["b"]), "Group should contain v_s['a']"
  assert g.contains_any(v_s_t), "Group should contain v_s_t['a',t]"
  assert not g.contains_all(v_s_t), "Group should not contain v_s_t['b',t]"
  assert g.contains_all(v_s_t['a',t]), "Group should contain v_s_t['a',t]"
  assert not g.contains_any(v_s_t['b',t]), "Group should not contain v_s_t['b',t]"
  
  g -= v_s['a']
  assert not g.contains_any(v_s['a']), "Group should not contain v_s['a']"
  assert not g.contains_all(v_s), "Group should not contain v_s['a']"
  assert g.contains_any(v_s), "Group should contain v_s['b']"