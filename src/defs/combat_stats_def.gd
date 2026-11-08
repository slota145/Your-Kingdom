class_name CombatStatsDef
extends Resource
## How a unit fights (ARCHITECTURE §10, M7). Starting values: ROADMAP M7.

@export_range(1, 9999) var hp: int = 100
@export_range(0, 999) var attack: int = 10
@export_range(0.1, 10.0) var attack_cooldown: float = 1.5
## Tiles; 1 = melee.
@export_range(1, 20) var attack_range: int = 1
## Walking speed against a civilian (a rider: 2).
@export_range(0.1, 4.0) var speed: float = 1.0
## Damage multiplier against other units: unit id -> factor (a spearman x2 against riders).
@export var bonus_vs: Dictionary[StringName, float] = {}
