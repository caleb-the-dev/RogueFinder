class_name VendorData
extends Resource

## --- VendorData ---
## One vendor archetype. Vendors own what categories of goods they sell and
## whether they appear in the world (WORLD) or only inside Badurga (CITY).
##
## category_pool drives what EquipmentLibrary / ConsumableLibrary buckets
## VendorScene samples from when generating stock. stock_count is the target
## number of items to offer — actual stock may vary if the bucket runs dry.

@export var vendor_id:       String        = ""
@export var display_name:    String        = ""
@export var flavor:          String        = ""
@export var category_pool:   Array[String] = []  # values: "weapon" | "armor" | "accessory" | "consumable"
@export var stock_count:     int           = 4
@export var scope:           String        = "WORLD"  # "CITY" or "WORLD"
