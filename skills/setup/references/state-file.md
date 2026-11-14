# State file

The repository state file is `.agentic-coding.json`. It is the deterministic
record of a successful toolkit reconciliation, not a transcript of the setup
conversation.

## Schema

```json
{
  "schemaVersion": 1,
  "release": { "ref": "v1.2.3", "channel": "stable", "commit": "40-character-sha" },
  "scope": { "skills": "project", "nativeAgents": "project" },
  "harnesses": ["claude-code", "opencode", "codex"],
  "skillDistribution": {
    "claude-code": { "authored": "plugin", "thirdParty": "vercel-cli" },
    "opencode": { "authored": "vercel-cli", "thirdParty": "vercel-cli" },
    "codex": { "authored": "vercel-cli", "thirdParty": "vercel-cli" }
  },
  "configuration": { "opencodeModelProfile": "opencode-go-openai", "contributions": {} },
  "managedAssets": [],
  "retained": []
}
```

`schemaVersion` is the integer version of this state format. `release` is an
object containing the selected `ref`, its `channel` (`stable` or `preview`),
and the immutable 40-character lowercase commit resolved for the release.

| Field | Allowed shape or values | Persisted data |
|---|---|---|
| `schemaVersion` | Integer | Version of this state format. |
| `release` | Object | Selected release metadata. |
| `release.ref` | String | Selected release reference. |
| `release.channel` | `stable` or `preview` | Selected release channel. |
| `release.commit` | Lowercase 40-character hexadecimal string | Immutable commit resolved for the release. |
| `scope` | Object | Skill, native-agent, and plugin-file scopes. |
| `scope.skills`, `scope.nativeAgents` | `project` or `global` | Each scope independently; the `nativeAgents` scope covers native agents and plugin files. |
| `harnesses` | Array of harness identifier strings | Configured harnesses. |
| `skillDistribution` | Object keyed by harness | Authored and third-party skill distribution channels for each harness. |
| `skillDistribution.<harness>.authored`, `skillDistribution.<harness>.thirdParty` | `plugin` or `vercel-cli` | The installation channel for each skill category. |
| `configuration` | Object | Harness configuration selections and contributions. |
| `configuration.opencodeModelProfile` | String | Selected OpenCode model profile: opencode-go, opencode-go-openai, opencode-go-mistral, or custom-retained. |
| `configuration.contributions` | Object keyed by configuration asset ID; each value contains a managed key/value map and `sourceHash` | Managed configuration values and the configuration asset source hash. |
| `managedAssets` | Array of objects | Managed asset records. |
| `managedAssets[].assetId` | String | Manifest asset identifier. |
| `managedAssets[].harness` | Harness identifier string | Harness associated with the asset. |
| `managedAssets[].scope` | `project` or `global` | Asset scope. |
| `managedAssets[].target` | Logical target; repository-relative for project assets and harness-logical for global assets, never an absolute home path | Asset target. |
| `managedAssets[].releaseHash` | String | Release hash associated with the asset. |
| `retained` | Array of objects | Retained asset records. |
| `retained[].assetId` | String | Asset identifier. |
| `retained[].target` | Logical target; repository-relative for project assets and harness-logical for global assets, never an absolute home path | Retained asset target. |
| `retained[].observedSource` | String or `null` | Observed source, or `null` when the source is unknown. |
| `retained[].reason` | Machine-readable reason string | Reason associated with the retained entry. |

Serialize with stable manifest order, sorted retained identifiers, and
consistent JSON formatting.
