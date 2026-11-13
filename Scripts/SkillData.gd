class_name SkillData
extends Resource

@export var id: String = "Bola_de_Fogo"
@export var skill_name: String = "Bola de Fogo"
@export var description: String = "Lança uma esfera de fogo."
@export var mana_cost: int = 25
@export var cooldown: float = 1.2
@export var requires_staff: bool = true
@export var type: String = "Area"
@export var icon: Texture2D = null # Ícone 2D ou textura para a barra e árvore de skills
@export var damage: int = 40
@export var effect_type: String = "queimadura"
@export var required_level : int = 1
@export var required_skill : String = ""
@export var animation_name: String = "Nadando"
