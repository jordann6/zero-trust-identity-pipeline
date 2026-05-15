resource "azurerm_logic_app_workflow" "incident_response" {
  name                = "zt-incident-response"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_logic_app_trigger_http_request" "sentinel_incident" {
  name         = "sentinel-incident-trigger"
  logic_app_id = azurerm_logic_app_workflow.incident_response.id

  schema = jsonencode({
    type = "object"
    properties = {
      incidentId  = { type = "string" }
      severity    = { type = "string" }
      title       = { type = "string" }
      status      = { type = "string" }
      description = { type = "string" }
    }
  })
}

resource "azurerm_logic_app_action_http" "notify_webhook" {
  name         = "notify-webhook"
  logic_app_id = azurerm_logic_app_workflow.incident_response.id
  method       = "POST"
  uri          = var.webhook_url

  body = jsonencode({
    text     = "Sentinel Incident Triggered"
    severity = "@{triggerBody()?['severity']}"
    title    = "@{triggerBody()?['title']}"
    incident = "@{triggerBody()?['incidentId']}"
  })

  headers = {
    "Content-Type" = "application/json"
  }

  depends_on = [azurerm_logic_app_trigger_http_request.sentinel_incident]
}

resource "azurerm_role_assignment" "sentinel_can_trigger_playbook" {
  scope                = azurerm_logic_app_workflow.incident_response.id
  role_definition_name = "Logic App Operator"
  principal_id         = var.sentinel_service_principal_id
}


