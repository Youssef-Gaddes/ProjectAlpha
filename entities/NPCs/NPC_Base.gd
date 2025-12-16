extends CharacterBody3D

@export var npcName:String
enum Factions { SCHOLAR, WARRIOR, KNIGHT, EXILE, MERCHANT, NONE }
@export var npcFaction: Factions
@export var can_talk: bool
@export var can_fight:bool
@export var Combat_Module:Node3D
@export var DialogueModule:Node3D


enum NPCState {
	PASSIVE,     # Just exists in world
	TALKING,     # Dialogue available     
	HOSTILE,     # Wants to fight
	ALLY,        # Helps player
	FLEEING,     # Exits Map
	DEAD
}
