#[tauri::command]
fn app_info() -> serde_json::Value {
    serde_json::json!({
        "name": "AI Studio Desktop",
        "mode": "fresh-build",
        "provider_protocol": "OpenAI-compatible"
    })
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![app_info])
        .run(tauri::generate_context!())
        .expect("error while running AI Studio Desktop");
}
