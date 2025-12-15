extends Node

var death_archetype: int = 0
var mercy_archetype: int = 0
var order_archetype: int = 0
var chaos_archetype:int = 0
var beaten_enemies:int = 0
var completed_runs:int = 0
var deaths:int = 0

var player_health:int 
var in_run:bool = false

func advance_death():
	death_archetype += 1
	print('death : ',death_archetype,'. mercy: ', mercy_archetype,' beaten enemies: ', beaten_enemies)
func advance_mercy():
	mercy_archetype += 1
	print('death : ',death_archetype,'. mercy: ', mercy_archetype,' beaten enemies: ', beaten_enemies)
	
