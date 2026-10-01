#########################################################################
# Example: grant Jump access to an existing key.
#
# Values below are placeholders. In a real onboarding they come from the
# tfvars file Jump generates for you.
#########################################################################

variable "project_id" {
  description = "Your project, holding the key."
  type        = string
}

module "jump_byok" {
  source = "../../"

  jump_deployment_location = "europe-west1"
  crypto_key_id            = "projects/example-keys/locations/europe-west1/keyRings/example-ring/cryptoKeys/example-key"

  # Jump's Cloud SQL, Cloud Storage and Compute service agents are granted by
  # default. Add any further identities Jump gives you during onboarding.
  additional_identities = {
    turbopuffer = "example@example.iam.gserviceaccount.com"
  }
}

output "granted_members" {
  value = module.jump_byok.granted_members
}
