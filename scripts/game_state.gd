# scripts/game_state.gd
extends Node

signal coins_changed(value: int)
signal key_changed(has_key: bool)

var coins: int = 0 : set = _set_coins
var has_key: bool = false : set = _set_has_key

func _set_coins(v: int) -> void:
	coins = max(0, v)
	coins_changed.emit(coins)

func add_coins(amount: int) -> void:
	_set_coins(coins + amount)

func _set_has_key(v: bool) -> void:
	has_key = v
	key_changed.emit(has_key)

func reset_level_state() -> void:
	_set_coins(0)
	_set_has_key(false)
