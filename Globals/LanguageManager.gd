extends Node

signal language_changed(new_lang: String)

const LANGUAGES_FILE_PATH: String = "res://languages.json"
const SETTINGS_FILE_PATH: String = "user://language_settings.cfg"
const BASE_LANGUAGE: String = "pt-br"

const DEFAULT_DISPLAY_NAMES: Dictionary = {
	"pt-br": "Português",
	"en-us": "English",
	"es-es": "Español"
}

var translations: Dictionary = {}
var current_language: String = BASE_LANGUAGE

func _ready() -> void:
	load_languages()
	_load_saved_language()

func load_languages() -> void:
	if not FileAccess.file_exists(LANGUAGES_FILE_PATH):
		push_warning("[LanguageManager] Arquivo languages.json não encontrado em: " + LANGUAGES_FILE_PATH)
		return

	var file := FileAccess.open(LANGUAGES_FILE_PATH, FileAccess.READ)
	if not file:
		push_warning("[LanguageManager] Não foi possível abrir languages.json")
		return

	var json_text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_text)
	if parsed is Dictionary:
		translations = parsed
	else:
		push_warning("[LanguageManager] Erro ao fazer parse de languages.json")

func _load_saved_language() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE_PATH) == OK:
		var saved_lang: String = str(cfg.get_value("general", "language", BASE_LANGUAGE))
		if translations.has(saved_lang):
			current_language = saved_lang
			return
	current_language = BASE_LANGUAGE

func set_language(lang_code: String) -> void:
	if not translations.has(lang_code):
		return
	if current_language == lang_code:
		return

	current_language = lang_code
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", current_language)
	cfg.save(SETTINGS_FILE_PATH)

	language_changed.emit(current_language)

func get_available_languages() -> Array[String]:
	var langs: Array[String] = []
	for key in translations.keys():
		if translations[key] is Dictionary:
			langs.append(str(key))
	return langs

func get_language_display_name(lang_code: String) -> String:
	if translations.has(lang_code) and translations[lang_code] is Dictionary:
		var lang_dict: Dictionary = translations[lang_code]
		if lang_dict.has("_language_name"):
			return str(lang_dict["_language_name"])
	if DEFAULT_DISPLAY_NAMES.has(lang_code):
		return str(DEFAULT_DISPLAY_NAMES[lang_code])
	return lang_code.to_upper()

func tr_key(key: String, default_text: String = "") -> String:
	if translations.has(current_language) and translations[current_language] is Dictionary:
		var current_dict: Dictionary = translations[current_language]
		if current_dict.has(key) and str(current_dict[key]) != "":
			return str(current_dict[key])

	# Fallback para o idioma base (Português)
	if current_language != BASE_LANGUAGE and translations.has(BASE_LANGUAGE) and translations[BASE_LANGUAGE] is Dictionary:
		var base_dict: Dictionary = translations[BASE_LANGUAGE]
		if base_dict.has(key) and str(base_dict[key]) != "":
			return str(base_dict[key])

	return default_text if default_text != "" else key

func tr_quest_title(quest_id: String, fallback: String = "") -> String:
	return tr_key("quest_%s_title" % quest_id, fallback)

func tr_quest_desc(quest_id: String, fallback: String = "") -> String:
	return tr_key("quest_%s_desc" % quest_id, fallback)

func tr_item_name(item_id: String, fallback: String = "") -> String:
	return tr_key("item_%s_name" % item_id, fallback)

func tr_item_desc(item_id: String, fallback: String = "") -> String:
	return tr_key("item_%s_desc" % item_id, fallback)
