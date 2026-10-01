# terraform-google-byok

Terraform module for configuring bring-your-own-key (BYOK) encryption for Jump.

Your engineers apply it, in your own Google Cloud project, against a key you
own and control. Jump only has permission
to encrypt and decrypt with the key while you choose to allow it.

## At a glance

### Which region should the key be in?

The region your Jump data is hosted in. Use a single-region key, not a
multi-region one (`us`, `europe`):

| Jump deployment | Key location |
| --- | --- |
| United States | `us-central1` |
| Canada | `northamerica-northeast1` |
| Europe | `europe-west1` |

Cloud KMS only lets a resource use a key in the same location as the
resource, so a key anywhere else cannot be used. At plan time the module checks
that your key is in the location you pass as `jump_deployment_location`.

### Which Google identities need access?

| Identity | What it encrypts |
| --- | --- |
| `service-228790252436@gcp-sa-cloud-sql.iam.gserviceaccount.com` | Your database and its backups (Cloud SQL) |
| `service-228790252436@gs-project-accounts.iam.gserviceaccount.com` | Your stored files (Cloud Storage) |
| `service-228790252436@compute-system.iam.gserviceaccount.com` | Your disks (Compute Engine) |
| `bq-228790252436@bigquery-encryption.iam.gserviceaccount.com` | Your analytics datasets (BigQuery) |
| Identities from onboarding (`additional_identities`) | For example, the vector store that holds your embeddings |

The first four are Google-managed service agents belonging to Jump's
production Google Cloud project (project number `228790252436`). They are the
same for every Jump customer, and the module grants them by default. They are
identifiers, not credentials: no one can sign in as them or create keys for
them, and Google uses them only on behalf of resources in Jump's project that
Jump has configured to use your key.

### Which roles or permissions do they need?

`roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key, and nothing else. No
access to your project, no other keys, no admin or viewer roles.

### How do I test key rotation?

Rotate the key as you normally would; Jump keeps working. Keep every earlier
key version enabled. See [Rotation](#rotation).

### How do I test revocation?

Remove the grants (`terraform destroy` on this module) or disable the key
version, and Jump can no longer encrypt or decrypt your data. Restoring the
grants or re-enabling the version brings service back. Please tell Jump before
you test. See [Revocation](#revocation).

## Requirements

| | Version |
| --- | --- |
| Terraform | `>= 1.9` |
| `hashicorp/google` provider | `>= 5.0` |

Terraform 1.9 is needed for the plan-time location check. If that floor is a
problem for your platform team, tell Jump.

## Before you apply

- **The Cloud KMS API** must be enabled in the project holding the key.
- **You need `roles/cloudkms.admin`** (or equivalent) on the key.

## Usage

Jump's service agents are built in, so you supply only your key, its location,
and any identities Jump gives you during onboarding.

```hcl
module "jump_byok" {
  source  = "Jump-App/byok/google"
  version = "~> 1.0"
  # Or, over SSH from GitHub instead of the registry (replaces both lines above):
  # source = "git::ssh://git@github.com/Jump-App/terraform-google-byok.git?ref=v1.0.0"

  jump_deployment_location = "europe-west1"
  crypto_key_id            = "projects/your-keys/locations/europe-west1/keyRings/your-ring/cryptoKeys/jump"

  # Only if Jump gives you further identities during onboarding:
  # additional_identities = {
  #   vector_store = "<address supplied by Jump>"
  # }
}
```

```
terraform init
terraform plan
terraform apply
```

Then send Jump the `granted_members` output to confirm the grants landed.

A worked example is in [`examples/complete`](examples/complete).

## Setting up without Terraform

The module only grants access to a key you already have. If you would rather
not use Terraform, you can create the key and grant the same access by hand,
with the `gcloud` CLI or in the Google Cloud console. Either way, the result is
the same as applying the module: the identities above get
`roles/cloudkms.cryptoKeyEncrypterDecrypter` on your key, and nothing else.

<details>
<summary><strong>With the gcloud CLI</strong></summary>

Set the project that will hold the key, and the key location for your
deployment from the [region table](#which-region-should-the-key-be-in):

```sh
PROJECT=your-key-project
LOCATION=europe-west1
KEYRING=jump-byok
KEY=jump
```

Enable Cloud KMS, then create a key ring and a key:

```sh
gcloud services enable cloudkms.googleapis.com --project="$PROJECT"

gcloud kms keyrings create "$KEYRING" \
  --location="$LOCATION" --project="$PROJECT"

gcloud kms keys create "$KEY" \
  --keyring="$KEYRING" --location="$LOCATION" --project="$PROJECT" \
  --purpose=encryption
```

To rotate the key automatically, add `--rotation-period=90d` and
`--next-rotation-time=<first rotation, e.g. 2027-01-01T00:00:00Z>`. Add
`--protection-level=hsm` for an HSM-backed key.

Grant Jump's identities access to the key. Add any identities Jump gave you
during onboarding to the list:

```sh
for SA in \
  service-228790252436@gcp-sa-cloud-sql.iam.gserviceaccount.com \
  service-228790252436@gs-project-accounts.iam.gserviceaccount.com \
  service-228790252436@compute-system.iam.gserviceaccount.com \
  bq-228790252436@bigquery-encryption.iam.gserviceaccount.com
do
  gcloud kms keys add-iam-policy-binding "$KEY" \
    --keyring="$KEYRING" --location="$LOCATION" --project="$PROJECT" \
    --member="serviceAccount:$SA" \
    --role=roles/cloudkms.cryptoKeyEncrypterDecrypter
done
```

Check the grants, and get the key's full resource ID to send to Jump:

```sh
gcloud kms keys get-iam-policy "$KEY" \
  --keyring="$KEYRING" --location="$LOCATION" --project="$PROJECT"

gcloud kms keys describe "$KEY" \
  --keyring="$KEYRING" --location="$LOCATION" --project="$PROJECT" \
  --format='value(name)'
```

To revoke access later, run the same loop with `remove-iam-policy-binding` in
place of `add-iam-policy-binding`.

</details>

<details>
<summary><strong>In the Google Cloud console</strong></summary>

1. In the project that will hold the key, open **Security → Key Management**.
   Enable the Cloud KMS API if prompted.
2. Click **Create key ring**. Give it a name, set **Location type** to
   **Region**, and choose the key location for your deployment from the
   [region table](#which-region-should-the-key-be-in). Do not choose a
   multi-region location.
3. Enter a name for a new key. Choose protection level **Software** (or
   **HSM**), key material **Generated key**, and purpose **Symmetric
   encrypt/decrypt**. Set rotation or other optional settings as desired.
   Finally choose **Create**.
4. Click on the key name and go to the **Permissions** tab. Click **Grant
   access**.
5. Under **New principals**, add each of these, plus any identities Jump gave
   you during onboarding:
   - `service-228790252436@gcp-sa-cloud-sql.iam.gserviceaccount.com`
   - `service-228790252436@gs-project-accounts.iam.gserviceaccount.com`
   - `service-228790252436@compute-system.iam.gserviceaccount.com`
   - `bq-228790252436@bigquery-encryption.iam.gserviceaccount.com`
6. Under **Role**, choose **Cloud KMS CryptoKey Encrypter/Decrypter**, then
   click **Save**.
7. From the key's actions menu, choose **Copy resource name**, and send it to
   Jump.

To revoke access later, remove these principals on the key's **Permissions**
tab.

</details>

## Inputs

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `jump_deployment_location` | `string` | yes | Your deployment's key location, from the region table above |
| `crypto_key_id` | `string` | yes | Full resource ID of your key: `projects/<project>/locations/<location>/keyRings/<ring>/cryptoKeys/<key>` |
| `jump_service_agents` | `map(string)` | no | Jump's four service agents, keyed by system. Defaults to the addresses above; override only if Jump asks you to |
| `additional_identities` | `map(string)` | no | Further identities needing encrypt/decrypt, keyed by system. Defaults to none |

## Outputs

| Name | Description |
| --- | --- |
| `crypto_key_id` | The key the grants were applied to |
| `granted_members` | Every identity granted access, and the role it received |

`granted_members` is the complete extent of Jump's access to this key. It is
meant to be read by your security reviewers and kept alongside your own
records.

## Rotation and revocation

The key's lifecycle stays entirely with you. The module never creates, rotates
or destroys it, and Jump has no visibility into its state, its rotation
schedule, or your KMS audit logs.

### Rotation

Rotation does not re-encrypt existing data. New writes use the new primary
version; data already written stays encrypted under the version that wrote it.
Disabling or destroying an earlier version therefore makes the data under it
unreadable, so keep every version enabled while data encrypted under it still
exists.

### Revocation

Access is yours to withdraw at any time, without involving Jump.

**Reversible - removes Jump's access, keeps your data recoverable.** Disable
the key version, or remove the grants (`terraform destroy` on this module).
Jump can no longer encrypt or decrypt your data and your service stops working;
restoring access brings it back.

**Irreversible - destroys the data.** Destroying key versions permanently
renders everything encrypted under them unreadable, by anyone, including you.
That includes backups: anything backed up under the key is lost along with the
live data. Cloud KMS enforces a scheduled-destruction delay before destruction
takes effect.

**Please tell Jump before doing either deliberately.** Not for permission - you
do not need it. But Jump cannot see the key, so advance notice is the only
signal it gets. Without it the first sign is your service failing, handled as
an unexplained outage rather than a controlled shutdown.

## Submodules

| Module | Purpose |
| --- | --- |
| [`modules/cmek-grants`](modules/cmek-grants) | The KMS IAM grants. Use the root module rather than this directly |

## License

Apache License 2.0. See [LICENSE](LICENSE).

The license covers this Terraform code only. It does not govern the access the
module grants, Jump's handling of your key, or any commitment made in your
agreement with Jump - those live in that agreement, and nothing in this
license's warranty disclaimer limits them.
