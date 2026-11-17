class_name BossSkillData
extends Resource

enum ShapeType { CIRCLE, CONE, RECTANGLE }
enum OriginType { CASTER, TARGET } # CASTER = Sai do Boss | TARGET = Nasce no pé do Player

@export var skill_name: String = "Golpe Pesado"
@export var damage: float = 50.0
@export var cast_time: float = 2.0
@export var cooldown: float = 8.0
@export var min_range: float = 0.0
@export var max_range: float = 12.0 # Aumente o max_range para magias à distância!
@export var animation_name: String = "skill_1"

@export_group("Configuração do Telegraph")
@export var origin_type: OriginType = OriginType.CASTER
@export var shape_type: ShapeType = ShapeType.CIRCLE
@export var area_size: Vector2 = Vector2(4.0, 4.0)
@export var forward_offset: float = 0.0
@export var cone_angle: float = 90.0
@export var vfx_scene: PackedScene
