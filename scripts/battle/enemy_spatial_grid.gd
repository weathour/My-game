extends RefCounted
## Bounded local crowd-spacing query; damage and targeting never use this approximation.
const CELL := 96.0
const MAX_NEIGHBORS := 32
var buckets := {}
var cells := {}
var maximum_radius := 0.0
var candidate_visits := 0

func rebuild(enemies: Array) -> void:
	buckets.clear();cells.clear();maximum_radius=0.0;candidate_visits=0
	for enemy in enemies:
		if enemy.dead or not enemy.targetable: continue
		maximum_radius=maxf(maximum_radius,float(enemy.radius))
		var key:=Vector2i(floori(enemy.position.x/CELL),floori(enemy.position.y/CELL))
		if not buckets.has(key): buckets[key]=[]
		buckets[key].append(enemy);cells[enemy.id]=key

func nearby(enemy: RefCounted) -> Array:
	var result: Array=[]
	var reach: float=enemy.radius+maximum_radius
	var home:=Vector2i(floori(enemy.position.x/CELL),floori(enemy.position.y/CELL))
	var rings:=ceili(reach/CELL)
	# Visit the local cell before surrounding cells. Cap only cosmetic spacing work.
	for ring in range(rings+1):
		for x in range(-ring,ring+1):
			for y in range(-ring,ring+1):
				if maxi(absi(x),absi(y))!=ring: continue
				for other in buckets.get(home+Vector2i(x,y),[]):
					if other==enemy or other.dead or not other.targetable: continue
					candidate_visits+=1
					result.append(other)
					if result.size()>=MAX_NEIGHBORS: return result
	return result

func moved(enemy: RefCounted) -> void:
	var previous: Vector2i=cells.get(enemy.id,Vector2i(-999,-999))
	var current:=Vector2i(floori(enemy.position.x/CELL),floori(enemy.position.y/CELL))
	if current==previous: return
	if buckets.has(previous): buckets[previous].erase(enemy)
	if not buckets.has(current): buckets[current]=[]
	buckets[current].append(enemy);cells[enemy.id]=current
