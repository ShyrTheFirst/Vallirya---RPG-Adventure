class_name SpawnEntry
extends Resource

@export var scene: PackedScene
@export var monster_name: String = ""
@export var count: int = 3
@export var min_level: int = 1
@export var max_level: int = 3
@export var drop_table: Array[MonsterDrop] = []

@export_category("Sobrescrita de Criatura (-1 = usar padrão da cena)")
@export var speed: float = -1.0
@export var leash_radius: float = -1.0
@export var aggro_range: float = -1.0
@export var max_chase_distance: float = -1.0
@export var base_attack_range: float = -1.0
@export var attack_effect: String = ""
@export var effect_damage_percent: float = -1.0

@export_category("Sobrescrita de Arquétipo (-1 = usar padrão da cena)")
@export var hp_factor: float = -1.0
@export var atk_factor: float = -1.0
@export var def_factor: float = -1.0
@export var attack_cooldown_base: float = -1.0
@export var respawn_time: float = -1.0
