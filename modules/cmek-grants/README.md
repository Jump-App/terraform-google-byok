# cmek-grants

Grants a set of service accounts permission to use one Cloud KMS key.

Consume the [root module](../../) instead of this one unless you have a
specific reason not to — the root module is the supported entry point and the
one Jump's onboarding generates values for.

## What it creates

One `google_kms_crypto_key_iam_member` per entry in
`encrypter_decrypter_members`, granting
`roles/cloudkms.cryptoKeyEncrypterDecrypter`. Nothing else.

The `_member` form is deliberate. It is additive, so it adds exactly these
bindings and leaves the rest of the key's IAM policy alone. The authoritative
forms (`_binding`, `_policy`) would take ownership of the policy and silently
remove bindings this module does not know about.

## Requirements

Terraform `>= 1.9`, `hashicorp/google` provider `>= 5.0` — matching the root
module, though this submodule itself uses no feature newer than 1.3.

## Inputs

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `crypto_key_id` | `string` | yes | Full resource ID of the key |
| `encrypter_decrypter_members` | `map(string)` | yes | Service accounts to grant encrypt/decrypt, keyed by system |

Map keys become Terraform resource addresses, so they must stay stable across
applies. Changing a value updates that binding in place; changing a key
destroys and recreates it.

## Outputs

| Name | Description |
| --- | --- |
| `granted_members` | Every principal granted access, and the role it received |
