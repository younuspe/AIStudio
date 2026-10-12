#[tauri::command]
fn app_info() -> serde_json::Value {
    serde_json::json!({
        "name": "AI Studio Desktop",
        "mode": "fresh-build",
        "provider_protocol": "OpenAI-compatible"
    })
}

#[tauri::command]
async fn provider_chat(base_url: String, api_key: String, body: serde_json::Value) -> Result<serde_json::Value, String> {
    let endpoint = format!("{}/chat/completions", base_url.trim_end_matches('/'));
    let client = reqwest::Client::new();
    let mut request = client.post(&endpoint).json(&body);
    if !api_key.trim().is_empty() {
        request = request.bearer_auth(api_key.trim());
    }
    let response = request.send().await.map_err(|e| format!("Could not reach provider: {e}"))?;
    let status = response.status();
    let text = response.text().await.map_err(|e| format!("Could not read provider response: {e}"))?;
    if !status.is_success() {
        return Err(format!("Provider returned HTTP {status}: {}", text.chars().take(600).collect::<String>()));
    }
    serde_json::from_str(&text).map_err(|e| format!("Provider returned invalid JSON: {e}. Response: {}", text.chars().take(300).collect::<String>()))
}

#[tauri::command]
async fn provider_models(base_url: String, api_key: String) -> Result<serde_json::Value, String> {
    let endpoint = format!("{}/models", base_url.trim_end_matches('/'));
    let client = reqwest::Client::new();
    let mut request = client.get(&endpoint);
    if !api_key.trim().is_empty() {
        request = request.bearer_auth(api_key.trim());
    }
    let response = request.send().await.map_err(|e| format!("Could not reach provider: {e}"))?;
    let status = response.status();
    let text = response.text().await.map_err(|e| format!("Could not read provider response: {e}"))?;
    if !status.is_success() {
        return Err(format!("Provider returned HTTP {status}: {}", text.chars().take(600).collect::<String>()));
    }
    serde_json::from_str(&text).map_err(|e| format!("Provider returned invalid JSON: {e}"))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![app_info, provider_chat, provider_models])
        .run(tauri::generate_context!())
        .expect("error while running AI Studio Desktop");
}
