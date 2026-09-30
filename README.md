# terraform-google-byok

Terraform module for configuring bring-your-own-key (BYOK) encryption for Jump
in your own Google Cloud project.

You run this. It is applied by your engineers, in your project, against a key
you own and control. Jump never has a copy of the key material — only
permission to call encrypt and decrypt on the key while you choose to allow it.

## What it does

Grants a small, explicit set of Google Cloud service accounts permission to use
one Cloud KMS key:

| Principal | Role | Why |
| --- | --- | --- |
| Jump's Cloud SQL, Cloud Storage and Compute service agents | `roles/cloudkms.cryptoKeyEncrypterDecrypter` | Encrypt your database, disks and objects at rest with your key |
| Jump's vector store service account | `roles/cloudkms.cryptoKeyEncrypterDecrypter` | Encrypt your embeddings with your key |

That is the entire set. The grants are additive — they add exactly these
bindings and leave every other IAM binding on the key untouched.

## What it does not do

- It does not grant Jump access to your project, your data, or any other key.
- It does not create, own, rotate or destroy your key. Key lifecycle stays
  entirely with you.
- It does not move key material anywhere. Encryption and decryption happen
  inside Cloud KMS, in your project, under your audit logging.
- It does not give Jump any visibility into the key itself. Jump cannot read
  its state, its rotation schedule, or your KMS audit logs. See "Revoking
  access" for what that means in practice.

## Requirements

| | Version |
| --- | --- |
| Terraform | `>= 1.9` |
| `hashicorp/google` provider | `>= 5.0` |

Terraform 1.9 is required for cross-variable validation, which is how the
module checks your key's location against your deployment's at plan time. On an
older version `terraform init` fails with an unsupported-version error before
anything else runs. If that floor is a problem for your platform team, tell
Jump — the check can be expressed a different way.

## Before you apply

- **The Cloud KMS API** must be enabled in the project holding the key.
- **The key's location must match** the location of the resources it protects.
  Jump tells you which location that is during onboarding — it is specific to
  your deployment, not a blanket policy — and you pass it as
  `jump_deployment_location`. The module compares it against the key you supply
  and fails at plan time on a mismatch, rather than letting the error surface
  when Jump tries to build on the key.
- **You need `roles/cloudkms.admin`** (or equivalent) on the key to apply this.

## Usage

Jump generates a `.tfvars` file for you during onboarding. Use it rather than
transcribing addresses by hand — most of them embed a numeric project ID, and a
single wrong digit produces a binding that applies cleanly against a principal
that does not exist. The failure does not surface until Jump tries to create
the encrypted resource.

```hcl
module "jump_byok" {
  source  = "Jump-App/byok/google"
  version = "~> 1.0"

  jump_deployment_location = "europe-west1"
  crypto_key_id            = "projects/your-keys/locations/europe-west1/keyRings/your-ring/cryptoKeys/jump"

  jump_service_agents = {
    cloudsql    = "service-000000000000@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    storage     = "service-000000000000@gs-project-accounts.iam.gserviceaccount.com"
    compute     = "service-000000000000@compute-system.iam.gserviceaccount.com"
    turbopuffer = "..."
  }
}
```

```
terraform init
terraform plan
terraform apply
```

Then send Jump the `granted_members` output to confirm the grants landed.

A worked example is in [`examples/complete`](examples/complete).

## Inputs

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `jump_deployment_location` | `string` | yes | Cloud KMS location agreed during onboarding; your key must be in it |
| `crypto_key_id` | `string` | yes | Full resource ID of your key: `projects/<project>/locations/<location>/keyRings/<ring>/cryptoKeys/<key>` |
| `jump_service_agents` | `map(string)` | yes | Service accounts needing encrypt/decrypt, keyed by system |

No input has a default. Every value is supplied explicitly at onboarding, so
that each one gets looked at rather than inherited.

## Outputs

| Name | Description |
| --- | --- |
| `crypto_key_id` | The key the grants were applied to |
| `granted_members` | Every principal granted access, and the role it received |

`granted_members` is the complete extent of Jump's access to this key. It is
meant to be read by your security reviewers and kept alongside your own
records.

## Revoking access

Access is yours to withdraw at any time, without involving Jump.

**Reversible — removes Jump's access, keeps your data recoverable.** Disable
the key version, or remove the IAM bindings (`terraform destroy` on this
module). Jump loses the ability to decrypt immediately; your service stops
working, and re-enabling restores it.

**Irreversible — destroys the data.** Destroying key versions permanently
renders everything encrypted under them unreadable, by anyone, including you.
Cloud KMS enforces a scheduled-destruction delay before this takes effect.

**Please tell Jump before doing either deliberately.** Not for permission — you
do not need it. But this module grants Jump no visibility into the key, so
advance notice is the only signal Jump gets. Without it the first sign is your
service failing, handled as an unexplained outage rather than a controlled
shutdown.

## Two things that routinely surprise people

**Rotation does not re-encrypt existing data.** New writes use the new key
version; data already written stays encrypted under the version that wrote it.
Old versions therefore cannot be destroyed while data encrypted under them
still exists.

**Backups are encrypted under your key too.** If the key becomes unusable,
backups taken while it was in effect become unrecoverable along with the live
data. Restoring from backup requires the key.

## Submodules

| Module | Purpose |
| --- | --- |
| [`modules/cmek-grants`](modules/cmek-grants) | The KMS IAM bindings |

The root module is the supported entry point. Submodules exist so that future
capability arrives as an additional submodule behind a new variable rather than
a breaking change to what you have already applied.

## License

Apache License 2.0. See [LICENSE](LICENSE).

The license covers this Terraform code only. It does not govern the access the
module grants, Jump's handling of your key, or any commitment made in your
agreement with Jump — those live in that agreement, and nothing in this
license's warranty disclaimer limits them.
