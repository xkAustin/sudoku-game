extends Node

const PRODUCT_NAME := "Sudoku Game"
const PACKAGE_ID := "io.github.xkaustin.sudokugame"
const APP_VERSION := "1.0.0"
const API_VERSION := "v1"
const ALGORITHM_VERSION := 1

# Public client configuration only. Replace these values for online features.
var supabase_url: String = ""
var supabase_anon_key: String = ""

func online_configured() -> bool:
	return supabase_url.begins_with("https://") and not supabase_anon_key.is_empty()
