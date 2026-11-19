class_name SkillData
extends Resource

@export var id: String = "Bola_de_Fogo"
@export var skill_name: String = "Bola de Fogo"
@export var description: String = "Lança uma esfera de fogo."
@export var mana_cost: int = 25
@export var cooldown: float = 1.2
@export var requires_staff: bool = true
@export var type: String = "Area"
@export var icon: Texture2D = null
@export var damage: int = 40
@export var effect_type: String = "queimadura"
@export var required_level : int = 1
@export var required_skill : String = ""
@export var animation_name: String = "Nadando"

@export_category("Configurações de Instanciação e Níveis")
@export var spell_scene: PackedScene # Cena .tscn que será instanciada no local do alvo/decal
@export var max_level: int = 5      # Nível máximo que a skill pode alcançar
@export var damage_per_level: int = 15 # Quanto de dano o nível a mais adiciona
