extends Resource

# Accelerated laboratory values, not the balance of the full prologue.
@export_range(0, 100) var starting_food := 60.0
@export_range(0, 100) var starting_stamina := 100.0
@export_range(0, 10) var portions := 2
@export_range(0, 100) var food_per_portion := 35.0
@export_range(0, 10) var food_walking_per_second := 0.55
@export_range(0, 10) var food_idle_per_second := 0.12
@export_range(0, 10) var stamina_per_metre := 0.5
@export_range(0, 20) var stamina_standing_per_second := 1.2
@export_range(0, 20) var stamina_rest_per_second := 0.35
@export_range(1, 10) var stamina_run_multiplier := 3.0
@export_range(1, 10) var hungry_stamina_multiplier := 1.5
@export_range(0, 100) var warning_threshold := 30.0
@export_range(0, 1) var hungry_recovery_factor := 0.5
