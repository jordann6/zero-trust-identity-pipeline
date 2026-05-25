from diagrams import Diagram, Cluster, Edge
from diagrams.azure.identity import (
    AzureActiveDirectory,
    Users,
    AppRegistrations,
    EntraManagedIdentities,
    ConditionalAccess,
    ADPrivilegedIdentityManagement,
)
from diagrams.azure.security import KeyVaults, MicrosoftDefenderForCloud, AzureSentinel
from diagrams.azure.storage import StorageAccounts
from diagrams.azure.managementgovernance import LogAnalyticsWorkspaces, Monitor, Alerts
from diagrams.azure.integration import LogicApps
from diagrams.azure.devops import Pipelines

graph_attr = {
    "fontsize": "13",
    "bgcolor":  "white",
    "pad":      "0.6",
    "ranksep":  "1.0",
    "nodesep":  "0.6",
}

node_attr = {
    "fontsize": "11",
}

with Diagram(
    "Azure Zero Trust Identity Pipeline",
    filename="docs/architecture",
    outformat="png",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    # ── Layer 1 – Identity Plane ──────────────────────────────────────────────
    with Cluster("Identity Plane — Microsoft Entra ID"):
        entra  = AzureActiveDirectory("Entra ID\nTenant")
        users  = Users("Users & Groups")
        app    = AppRegistrations("App Registration\nOIDC Credential")
        mi     = EntraManagedIdentities("Managed Identity")
        ca     = ConditionalAccess("Conditional Access\n5 CA Policies")
        pim    = ADPrivilegedIdentityManagement("PIM\nEligible Roles")

    # ── Layer 2 – Workload Security ───────────────────────────────────────────
    with Cluster("Workload Security"):
        kv     = KeyVaults("Key Vault\nRBAC · No Access Policies")
        sa     = StorageAccounts("Storage Account\nOAuth Only · No Shared Keys")
        gh     = Pipelines("GitHub Actions\nOIDC Federated · No Secrets")

    # ── Layer 3 – Threat Detection ────────────────────────────────────────────
    with Cluster("Threat Detection"):
        dfc    = MicrosoftDefenderForCloud("Defender for Cloud\nKey Vault · Storage · ARM")
        law    = LogAnalyticsWorkspaces("Log Analytics Workspace\nCentral Log Store")
        sent   = AzureSentinel("Microsoft Sentinel\n5 MITRE ATT&CK Rules")

    # ── Layer 4 – Response & Alerting ─────────────────────────────────────────
    with Cluster("Response & Alerting"):
        la     = LogicApps("Logic App\nIncident Playbook")
        mon    = Monitor("Azure Monitor\n4 Activity Log Alerts")
        ag     = Alerts("Action Group\nEmail · Webhook")

    # ── Data flow ─────────────────────────────────────────────────────────────
    entra >> Edge(label="issues identity") >> [users, app, mi]
    entra >> Edge(label="enforces")        >> [ca, pim]

    app   >> Edge(label="federated auth")  >> gh
    mi    >> Edge(label="RBAC access")     >> kv
    mi    >> Edge(label="Blob Data Reader")>> sa

    [kv, sa] >> Edge(label="diag logs")   >> dfc
    dfc      >> Edge(label="exports to")  >> law
    law      >> Edge(label="ingests into")>> sent

    sent  >> Edge(label="triggers")       >> la
    la    >> Edge(label="notifies")       >> ag
    mon   >> Edge(label="alerts")         >> ag
