extends SceneTree
## Cuts the stone of the PixelLab repaint of the walls prototype (ART_SPEC §10.1, §10.15)
## into the textures the game draws stone walls with (M7 part 2):
##   assets/walls/stone/lit.png, dark.png, top.png: face and crown samples, seamless,
##   assets/walls/stone/gatehouse_body.png: the gatehouse of the repaint (passage along y),
##   assets/walls/stone/skin.json: where the samples start and how often they repeat.
## Run: "$GODOT" --headless --path . -s res://tools/make_wall_skin.gd

const RepaintSkin := preload("res://src/prototype/walls/repaint_skin.gd")
const DIR := "res://src/prototype/walls/pixellab/repaint/"
const OUT := "res://assets/walls/stone/"


func _init() -> void:
	var skin: RefCounted = RepaintSkin.load_from(DIR + "wall.png", DIR + "gate.png")
	var meta := {}
	for name: String in ["lit", "dark", "top"]:
		var sample: RefCounted = skin.get(name)
		(sample.texture as Texture2D).get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		meta[name] = {"origin": [sample.origin.x, sample.origin.y], "period": [sample.period.x, sample.period.y],
				"height": sample.height}
	(skin.gatehouse as Texture2D).get_image().save_png(ProjectSettings.globalize_path(OUT + "gatehouse_body.png"))
	meta["gatehouse_pivot"] = [skin.gatehouse_pivot.x, skin.gatehouse_pivot.y]
	var mc: Color = skin.merlon_color
	var oc: Color = skin.outline
	meta["merlon"] = [mc.r, mc.g, mc.b]
	meta["outline"] = [oc.r, oc.g, oc.b]
	var file := FileAccess.open(OUT + "skin.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "\t"))
	file.close()
	print("wall skin written to ", OUT)
	quit()
