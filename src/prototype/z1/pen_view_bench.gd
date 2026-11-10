extends SceneTree
## Z1 part 4: what 100 animals walking in pens cost the view (PenLayer.update_view, CPU only, no
## drawing): 10 pigsties with 6 pen tiles and 10 pigs each, 3 apiaries with 8 hives.
## "$GODOT" --headless --path . -s res://src/prototype/z1/pen_view_bench.gd


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim := Simulation.new(registry, Vector2i(80, 80), 1)
	var p := sim.province
	for k: int in 10:
		var at := Vector2i(6 + (k % 5) * 14, 8 + (k / 5) * 20)
		p.add_building(registry.get_building(&"pigsty"), at, true)
		var sty := p.buildings.get_building(p.grid.occupant(at))
		Pens.auto_place(p, sty, 6)
		sty.yard.add(&"pig", 10 - sty.yard.total(&"pig"))
	for k: int in 3:
		var at := Vector2i(10 + k * 20, 60)
		p.add_building(registry.get_building(&"apiary"), at, true)
		Pens.auto_place(p, p.buildings.get_building(p.grid.occupant(at)), 8)
	var layer := PenLayer.new()
	root.add_child(layer)
	layer.setup(p)
	layer.update_view(0.016)
	var frames := 2000
	var t0 := Time.get_ticks_usec()
	for i: int in frames:
		layer.update_view(1.0 / 60.0)
	var animals := 0
	for herd: Array in layer._herds.values():
		animals += herd.size()
	print("%d animals, %d hives: %.3f ms per frame (PenLayer.update_view)" % [animals, layer._skeps.size(),
			(Time.get_ticks_usec() - t0) / 1000.0 / frames])
	quit()
