class_name AnimalKit
extends RefCounted

## Animal Kit — data-driven animal actors.
##
## A species is pure DATA: a JSON file in animal_kit/species/<id>.json
## (speed, damage, perception, aggression/fear flavour, sprites, scale).
## One actor scene class (Animal, animal.gd) plays every species; small
## "brains" (state machines) inside it are selected by the species' "brain"
## field. To add a species you add a JSON file — no new code.
##
## See animal_kit/README.md for the schema and for how GTA Fredericton
## would lift this kit into its own project.

const SPECIES_DIR := "res://animal_kit/species/"

static var _cache: Dictionary = {}


static func load_species(species_id: String) -> Dictionary:
    if _cache.has(species_id):
        return _cache[species_id]
    var path := SPECIES_DIR + species_id + ".json"
    var text := FileAccess.get_file_as_string(path)
    var data: Variant = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        push_error("AnimalKit: could not parse species file " + path)
        return {}
    _cache[species_id] = data
    return data


static func make_animal(species_id: String) -> Animal:
    var animal := Animal.new()
    animal.species_def = load_species(species_id)
    return animal
